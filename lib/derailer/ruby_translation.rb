$strings_used = []
$pred_names = []
$types_used = []
$class_fields_used = Hash.new

class Sexp
  def initialize(*args)
    @args = args
  end

  def to_s
    "Sexp.new(" + @args.map{|x| x.to_s}.join(", ") + ")"
  end
end


def used_class_field(klass, field)
#  puts "adding " + klass.to_s + ": " + field.to_s
  if $class_fields_used[klass] then
    # we have to make sure the type of this field is defined!
    if field.respond_to? :type then
      add_type_used(field.type)
    end

    if $class_fields_used[klass].include? field then
      #nothing
    else
      $class_fields_used[klass] << field
    end
  else
    $class_fields_used[klass] = [field]
  end
end

def add_type_used(type)
  if !$types_used.include? type and ![:bool, :Entity].include? type then
    $types_used << type
  end
end

class Object
  def to_ruby
    self.to_s.to_sym
  end
end


class NilClass
  def to_ruby
    :nil
  end
end

class Exp
  def type
    @type
  end

  def to_ruby
    if @args then
      args = @args.dup
    else
      args = []
    end

    # we should do something better here
    if @type == :params then # it will be a string or a HASH?!?!?!?!?!
      Sexp.new(:params, args.shift.to_ruby)
    elsif @type == :session then # it will be a string or a HASH?!?!?!?!?!
      Sexp.new(:session, args.shift.to_ruby)
    else
      add_type_used(@type)

      case args.length
      when 0 
        # class name
        @type.to_s
      when 1
        args.shift.to_ruby
      when 2 
        a = args.shift.to_ruby
        b = args.shift.to_ruby
        if @type == :Entity then
          Sexp.new(:dot, a, b)
        else
          if $class_fields[@type.to_s] then
            field = $class_fields[@type.to_s].select{|x| x.name.to_s == b.to_s}
            if field != [] and field.length == 1 then
              used_class_field(@type, field[0])
            end
          end

          if b.to_s == "to_sym" then
            a
          elsif a.to_s == "not" then
            Sexp.new(:not, b)
          else
            Sexp.new(:dot, a, b)
          end
        end
      else
        a = args.shift
        b = args.shift
        c = args.shift
        # binary ops
        if [:+, :-, :implies, :==, :and, :or].include? b then
          Sexp.new(b.to_ruby, a.to_ruby, c.to_ruby)
        elsif b == :query then
          Sexp.new(:find, a.to_ruby, c.to_ruby)
        else
          Sexp.new(:dot, [a.to_ruby, b.to_ruby, c.to_ruby] + args.map{|x| x.to_ruby})
        end
      end
    end
  end
end

class Class
  def to_ruby
    # do we need a side effect?
    self.to_s.to_sym
  end
end

class Symbol
  def to_ruby
    # side effect to define this symbol? maybe not
    self
  end
end

class Array
  def to_ruby
    self.map{|x| x.to_ruby}
  end
end

class String
  def to_ruby
    self
  end
end

class SymbolicArray
  def to_ruby
    @my_objs
  end

  alias :to_str :to_s
  def to_s
    to_ruby
  end
end
