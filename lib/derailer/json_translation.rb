$strings_used = []
$pred_names = []
$types_used = []
$class_fields_used = Hash.new

def used_class_field(klass, field)
#  puts "adding " + klass.to_s + ": " + field.to_s
  if $class_fields_used[klass] then
    # we have to make sure the type of this field is defined!
    add_type_used(field.type)

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

class Exp
  def type
    @type
  end

  def to_json
    args = @args.dup

    if @type == :params then # it will be a string or a HASH?!?!?!?!?!
      "params[" + args.shift.to_json + "]"
    else
      add_type_used(@type)

      case args.length
      when 0 
        # class name
        @type.to_s
      when 1
        args.shift.to_json
      when 2 
        a = args.shift.to_json
        b = args.shift.to_json
        if @type == :Entity then
          a + "." + b
        else
          field = $class_fields[@type].select{|x| x.name == b}
          
          if field != [] and field.length == 1 then
            used_class_field(@type, field[0])
            a + "." + b
          else raise "invalid field"
          end
        end
      else
        a = args.shift
        b = args.shift
        c = args.shift
        # binary ops
        if [:+, :-, :implies, :==].include? b then
          a.to_json + " " + b.to_s + " " + c.to_json
        elsif b == :query then
          name = a.to_json.downcase
          "{ " + name + " : " + a.to_json + " | " + name + ".id in " + c.to_json + " }"
        else
          raise "who knows wtf this is"
          #a.to_json + "." + b.to_json + "[" + args.map{|x| x.to_json}.join(", ") + "]"
        end
      end
    end
  end
end

class Class
  def to_json
    # do we need a side effect?
    self.to_s
  end
end

class Symbol
  def to_json
    # side effect to define this symbol? maybe not
    self.to_s
  end
end

class Array
  def to_json
    "[" + self.map{|x| x.to_json}.join(", ") + "]"
  end
end

class String
  def to_json
    self
  end
end
