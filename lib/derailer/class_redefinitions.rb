$gensym = 1
class Object
  $symbolic_execution = false
  $results = []

  alias :equals :==
  # alias :old_send :send
  # def send(meth, *args)
  #   if meth.is_a? Exp then
  #     Exp.new(:unknown, self, :send, meth, *args)
  #   else
  #     old_send(meth, *args)
  #   end
  # end

  def type
    :unknown
  end

  def metaclass
    class << self
      self
    end
  end

  alias :old_instance_variable_get :instance_variable_get
  alias :old_instance_variable_set :instance_variable_set

  def instance_variable_get(var)
    if var.is_a? Exp or var.to_s.starts_with? "@Exp" then
      log "USING MY instance variable get: " + self.to_s + "." + var.to_s
      var
    else
      self.old_instance_variable_get(var)
    end
  end

  def instance_variable_set(var, val)
    if var.is_a? Exp or var.to_s.starts_with? "@Exp" then
      log "USING MY instance variable set: " + self.to_s + "." + var.to_s + " = " + val.to_s
      Exp.new(:nil, self, :instance_variable_set, var, val)
    else
      self.old_instance_variable_set(var, val)
    end
  end

  def self.forall(&block)
    if $symbolic_execution then
      call_forall(block)
    else
      $symbolic_execution = true
      $results << call_forall(block)
      $symbolic_execution = false
    end
  end

  def call_forall(block)
    def mknew(n, k)
      vars = []
      (1..n).each do
        vars << Exp.new(k, k)
      end
      vars
    end

    klass = self

    if block.arity == -1 then
      vars = []
      result = block.call
    elsif block.arity == 1 then
      vars = mknew(1, klass)
      result = block.call(vars[0])
    elsif block.arity == 2 then
      vars = mknew(2, klass)
      result = block.call(vars[0], vars[1])
    else raise "error: forall called with more than two quantified vars"
    end


    vars.each do |v|
      metaklass = class << v; self; end

      name = "var" + $gensym.to_s
      $gensym = $gensym + 1

      metaklass.send(:define_method, :to_alloy, lambda { name })
    end

    # $objects_used = $objects_used + vars
    # $latest_objects = vars
    Exp.new(:forall, vars, result)
  end

  # alias :old_send :send

  # def send(m, *args)
  #   if m.is_a? Exp then
  #     Exp.new(m.type, self, m, *args)
  #   else
  #     old_send(m, *args)
  #   end
  # end

end

class Array
  alias :old_join :join

  def join(str="")
    if self.index{|x| x.is_a? Exp} then
      Exp.new(:string, self, :join, str)
    else
      self.old_join(str)
    end
  end

  def my_include?(other)
    if self.index {|e| (e.is_a? Exp and e.equals other) or (!e.is_a? Exp and e == other)} then
      true
    else false
    end
  end
end

class SymbolicArray < Array
  def initialize(type)
    @type = type
    @my_objs = Hash.new
  end

  def require(fld)
    e = Exp.new(@type, self)
    e.add_constraint(Exp.new(:bool, :field_required, fld))
    e
  end

  def join(str)
    Exp.new(:string, :join, self, str)
  end

  def [](key)
    if @my_objs.has_key? key
      @my_objs[key]
    else
      o = Exp.new(@type, key)
      @my_objs[key] = o
      o
    end
  end

  def []=(key, val)
    @my_objs[key] = val
  end

  # THIS IS PROBABLY WRONG!
  def method_missing(*args)
    #puts "called it " + args.to_s
    Exp.new(self, *args)
  end
end

# todo: more stuff should go here...
class SymbolicHash < Hash
  def initialize(contents)
    @contents = contents
  end

  def to_s
    "SymbolicHash(" + @contents.to_s + ")"
  end
end


def my_product(arrays)
  if arrays.empty? then []
  else
    first, *rest = arrays
    first.product(*rest)
  end
end

def flatten_exp(e)
  if e.is_a? Exp and !e.is_a? Choice then
    processed_args = e.args.map {|a| flatten_exp(a)}
    possibilities = my_product(processed_args)
    possibilities.map do |a|
      new_e = Exp.new(e.type, *a)
      e.constraints.each {|c| new_e.add_constraint(c)}
      new_e.set_updates(e.updates)
      new_e
    end
  elsif e.is_a? Choice then
    flatten_exp(e.left) + flatten_exp(e.right)
  else
    [e]
  end
end

def consolidate_constraints(e)
  e.args.each do |a|
    if a.is_a? Exp then
      consolidate_constraints(a)
      a.constraints.each do |c|
        e.add_constraint(c)
      end
    end
  end
end

class Exp
  def initialize(type, *args)
    @type = type
    @args = args
    @constraints = []
    @updates = []

    @args.each do |arg|
      if arg.is_a? Exp and arg.constraints != [] then
#        puts "WOOP transfer constraint " 
        arg.constraints.each {|x| add_constraint(x)}
      end
    end
  end

  def produce_write_constraint
    puts "produce write constraint: " + self.to_s

    if @type == :bool then
      first, op, second = @args
      puts "op is " + op.to_s
      case op.to_s
      when "or"
        [first.produce_write_constraint, second.produce_write_constraint]
      when "=="
        "impossible"
      end
    elsif @args.length == 2 then
      "TRYING: " + @type.to_s.constantize.to_s
    else
      "unimplemented " + @type.to_s.constantize.to_s
    end
      
  end

  def save
    puts "____ saving " + self.to_alloy + " with constraints"
    (self.constraints + $path_constraints).map{|x| x.to_alloy}.each do |c|
      puts "____  " + c.to_s
    end
    puts "____"

    to_save = self.dup
    $path_constraints.each do |c|
      to_save.add_constraint(c)
    end
    $saves << to_save
    
    Exp.new(@type, self, :save)
  end

  def each(&block)
    block.call(self)
  end

  def args
    @args
  end

  def class
    Exp.new(:Class, self, 'class')
  end

  def constraints
    @constraints
  end

  def updates
    @updates
  end

  def set_updates u
    @updates = u
  end

  def add_constraint(constraint)
    @constraints << constraint unless @constraints.my_include? constraint
  end

  def remove_constraints(constraints)
    @constraints = @constraints - constraints
  end


  def type
    @type
  end

  def coerce(other)
    puts "COERCING " + self.to_s + ", other: " + other.to_s
    [Exp.new(other.class, other), self]
  end

  def method
    Exp.new(@type, self, :method)
  end

  # def is_a? other
  #   Exp.new(:bool, self, other)
  # end

  def sort
    self
  end

  def find(query)
    Exp.new(@type, self, :query, query)
  end

  def to_descc
    @args[0].to_alloy + " : " + @type.to_alloy
  end

  def to_desc
    self.to_alloy + " : " + @type.to_s
  end
  
  def method_missing(meth, *args, &block)
    # general method:
    # check if last char is "=" and if so, apply some modification to self that records the update
    if meth.to_s[-1,1] == '=' then
      fname = meth.to_s[0..-2]
      @updates << Exp.new(@type, fname, :==, *args)
      puts "THIS IS " + self.to_s + " and my updates are " + self.updates.to_s
      self
    elsif @type.respond_to?(:method_defined?) and @type.method_defined?(meth) and @type.method_defined?(:new) then
      @type.new.send(meth, *args)
    elsif $class_fields[@type.to_s] and $class_fields[@type.to_s].map{|x| x.name.to_s + "="}.include? meth.to_s then
      self.add_constraint(Exp.new(:bool, Exp.new(:unknown, self, meth.to_s[0..-2]), :==, args.first))
    else
      Exp.new(@type, self, meth, *args)
    end
  end

  def to_hash
    SymbolicHash.new(self)
  end

  def to_ary
    SymbolicArray.new(:array)
  end
  alias :to_a :to_ary
  
  alias :to_str :to_s
  def to_s
    # to eliminate some stuff that we don't want in results
    def is_bad? str
      # WARNING this was eliminating some really important stuff
      return false
      ['new', 'to_key', 'errors', 'model_name'].each do |bad_str|
        return true if str.include? bad_str
      end
      return false
    end

    if $track_to_s then
      $track_to_s = false
      result = "Exp(" + @type.to_s + ", " + @args.map{|x| x.to_s}.join(", ") + ")"
      $track_to_s = true
      # TODO eliminating everything with "new" might be overkill
      $to_s_exps << self unless self.type == :unused or is_bad? result
    else
      result = "Exp(" + @type.to_s + ", " + @args.map{|x| x.to_s}.join(", ") + ")"
    end
    result
  end

  def ==(other)
    if $symbolic_execution then 
      Exp.new(:bool, self, :==, other)
    else
      #self == other
      puts "EEEE called equal: " + self.to_s + ", " + other.to_s
      self.type == other.type and
        self.args == other.args and
        self.constraints == other.constraints
    end
  end

  def implies(&block)
    Exp.new(:bool, self, :implies, block.call)
  end
end

class Choice < Exp
  def initialize(left, right)
    @left = left
    @right = right
  end

  def left
    @left
  end

  def right
    @right
  end

  def constraints
    cl = if @left then @left.constraints else [] end
    cr = if @right then @right.constraints else [] end
    cl + cr
  end

  def add_constraint(constraint)
    @left = Exp.new(@left.class.to_s, @left) unless @left.is_a? Exp
    @right = Exp.new(@right.class.to_s, @right) unless @right.is_a? Exp

    @left.add_constraint(constraint)
    @right.add_constraint(constraint)
  end
  
  def method_missing(meth, *args, &block)
    [@left, @right].each do |x|
      if x.type.respond_to?(:method_defined?) and x.type.method_defined?(meth) then
        # @type.new.send(meth, *args)
        log "ERROR: we should be calling a method here: " + x.to_s + ", " + meth.to_s
      end
    end

    # make a new choice node with my left and right
    # so that choices will always be at the top level
    Choice.new(Exp.new(@left.type, @left, meth, *args),
               Exp.new(@right.type, @right, meth, *args))
  end

  def to_s
    if $track_to_s then
      $track_to_s = false
      result = "Choice(" + @left.to_s + ", " + @right.to_s + ")"
      $track_to_s = true

      $to_s_exps << self # unless self.type == :unused or is_bad? result
    else
      result = "Choice(" + @left.to_s + ", " + @right.to_s + ")"
    end
    result
  end
end

# debatable whether or not this is a good idea....
class Class
  def find_by_api_key(key)
    "to_s"
  end
end

class Hash
  alias :old_v :[]
  # alias :old_init :initialize

  # def initialize(*args)
  #   if args.index{|v| v.is_a? Exp} then
  #     puts "IN SECOND"
  #     Exp.new(:Hash, args)
  #   else
  #     puts "IN FIRST " + args.to_s
  #     old_init(*args)
  #   end
  # end
  
  def [](obj)
    if obj.is_a? Exp then
      Exp.new(:new_hash, obj)
    else
      self.old_v(obj)
    end
  end
end


class Fixnum
  alias :old_plus :+
  
  def +(other)
    if other.is_a? Exp then
      Exp.new(:plus, self, other)
    else
      self.old_plus(other)
    end
  end
end

class String
  # DUBIOUS AT BEST
  alias :old_equals :==
  def ==(other)
    if other.is_a? String and (self.starts_with? "Exp" or other.starts_with? "Exp") then
      Exp.new(:bool, :==, self, other)
    else
      old_equals(other)
    end
  end
end

