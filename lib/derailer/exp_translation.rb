require 'json'

class Exp
  def to_exp
    if @args then
      "Exp.new(" + ([@type] + @args).map{|x| x.to_exp}.join(", ") + ")"
    else
      "Exp.new(" + @type.to_exp + ")"
    end
  end
end

class Object
  def to_exp
    JSON.generate(self.to_s, quirks_mode: true)
  end
end

class Symbol
  def to_exp
    JSON.generate(self.to_s, quirks_mode: true)
  end
end

class String
  def to_exp
    JSON.generate(self, quirks_mode: true)
  end
end

class NilClass
  def to_exp
    ":nil"
  end
end

class Hash
  def to_exp
    "{" + self.map{|k, v| k.to_exp + " => " + v.to_exp}.join(", ") + "}"
  end
end
