$strings_used = []
$pred_names = []
$types_used = []
$class_fields_used = Hash.new

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
  def to_alloy
    self.to_s
  end
end


class NilClass
  def to_alloy
    "nil"
  end
end

class Exp
  def type
    @type
  end

  def to_alloy
    if @args then
      args = @args.dup
    else
      args = []
    end

    # we should do something better here
    if @type == :params then # it will be a string or a HASH?!?!?!?!?!
      "params[" + args.shift.to_alloy + "]"
    elsif @type == :session then # it will be a string or a HASH?!?!?!?!?!
      "session[" + args.shift.to_alloy + "]"
    elsif @type == :forall then
      var = args.shift
      var_desc = var.map{|v| v.to_desc}.join(", ")
      body = args.shift
      "all " + var_desc + " | " + body.to_alloy
    elsif @type == :Proc then
      var = args.shift
      body = args.shift
      pred_name = "p" + $pred_names.length.to_s
      $pred_names << pred_name
      "pred " + pred_name + " [" + var.to_descc + "] { " + body.to_alloy + " }"
    else
      add_type_used(@type)

      case args.length
      when 0 
        # class name
        @type.to_s
      when 1
        args.shift.to_alloy
      when 2 
        a = args.shift.to_alloy
        b = args.shift.to_alloy
        if @type == :Entity then
          a + "." + b
        else
          #if not $class_fields[@type.to_s] then raise("couldn't find fields of type " + @type.to_s + " : " + @type.class.to_s) end
          if $class_fields[@type.to_s] then
            field = $class_fields[@type.to_s].select{|x| x.name.to_s == b.to_s}
            if field != [] and field.length == 1 then
              used_class_field(@type, field[0])
            end
          end

          if b.to_s == "to_sym" then
            a
          elsif a.to_s == "not" then
            "not " + b
          else
            a + "." + b
          end
        end

        #else raise "invalid field: " + field.to_s + " with name " + b.to_s + " from " + $class_fields[@type.to_s].to_s
      else
        a = args.shift
        b = args.shift
        c = args.shift
        # binary ops
        if [:+, :-, :implies, :==, :and, :or].include? b then
          a.to_alloy + " " + b.to_s + " " + c.to_alloy
        elsif b == :query then
          name = a.to_alloy.downcase
          "{ " + name + " : " + a.to_alloy + " | " + name + ".id in " + c.to_alloy + " }"
        # elsif a.to_s == "not" then
        #   "THIS SHOULD NOT hAVE HAPPENED (a not)"
        else
          #raise "who knows wtf this is"
          cp = c.to_alloy
          result = a.to_alloy + "." + b.to_alloy + "[" + ([c.to_alloy] + args.map{|x| x.to_alloy}).join(", ") + "]"
          if result.include? '\'' or result.include? '\"' then raise "found a string with newline: " + c.to_s end
          result
        end
      end
    end
  end
end

class Class
  def to_alloy
    # do we need a side effect?
    self.to_s
  end
end

class Symbol
  def to_alloy
    # side effect to define this symbol? maybe not
    self.to_s
  end
end

class Array
  def to_alloy
    "[" + self.map{|x| x.to_alloy}.join(", ") + "]"
  end
end

class String
  def to_alloy
    self
  end
end

class SymbolicArray
  def to_alloy
    "[" + @my_objs.to_s + "]"
  end

  alias :to_str :to_s
  def to_s
    to_alloy
  end
end
