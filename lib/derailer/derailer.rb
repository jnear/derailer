require 'rubygems'
#require 'virtual_keywords'
require 'set'
require 'json'
require 'sdg_utils/lambda/sourcerer'



def instr_src(src)
  ast = SDGUtils::Lambda::Sourcerer.parse_string(src)
  return "" unless ast
  orig_src = SDGUtils::Lambda::Sourcerer.read_src(ast)
  instr_src = SDGUtils::Lambda::Sourcerer.reprint(ast) do |node, parent, anno|
    new_src =
      case node.type
      when :if
          cond_src = SDGUtils::Lambda::Sourcerer.compute_src(node.children[0], anno)
          then_src = SDGUtils::Lambda::Sourcerer.compute_src(node.children[1], anno)
          else_src = SDGUtils::Lambda::Sourcerer.compute_src(node.children[2], anno)
          prepend = "(#{cond_src}); "
          if else_src.empty?
            prepend + "$analyzer.derailer_if(" +
              "lambda{#{cond_src}}, lambda{#{then_src}}, lambda{}) "
          else
            prepend + "$analyzer.derailer_if(" +
              "lambda{#{cond_src}}, " +
              "lambda{#{then_src}}, " +
              "lambda{#{else_src}})"
          end
      when :and, :or
          lhs_src = SDGUtils::Lambda::Sourcerer.compute_src(node.children[0], anno)
        rhs_src = SDGUtils::Lambda::Sourcerer.compute_src(node.children[1], anno)
        src = "$analyzer.derailer_and_or(:#{node.type}, " +
          "lambda{#{lhs_src}}, lambda{#{rhs_src}})"
        #puts "NEW SRC " + final.to_s
        src
      else
        nil
      end
  end
  instr_src
end


$symbolic_execution = false
$log = []
def log(msg)
  $log << msg
  puts msg
end

def without_symbolic(&block)
  sym = $symbolic_execution
  $symbolic_execution = false
  block.call
  $symbolic_execution = sym
end

log "LOADING DERAILER ********************************************************************************"

class Object
  def metaclass
    class << self
      self
    end
  end
end

DerailerField = Struct.new(:name, :type)

$all_vcs = Hash.new
def add_vcs(controller, action, vc)
  if $all_vcs[controller] then
    $all_vcs[controller][action] = vc
  else
    $all_vcs[controller] = Hash.new
    $all_vcs[controller][action] = vc
  end
end

def add_node(graph, type, exp, conditions, controller, action)
  type_colors = ["#7192DF", "#9DB1DF"]
  exp_colors = ["#65E2A2", "#97E2BC"]
  condition_colors = ["#D1F56E", "#E0F5A4"]
  controller_colors = ["#8D9280", "#F2F7E4"]
  action_colors = ["#ffffff", "#ffffff"]

  type_node = graph.add_child(type, type_colors, true)
  exp_node = type_node.add_child(exp, exp_colors, false)

  current_node = exp_node
  conditions.each do |c|
    current_node = current_node.add_child(c, condition_colors, true)
  end

  current_node.add_child(controller, controller_colors, true).add_child(action, action_colors, true)
end

def add_node_3(graph, type, exp, conditions, controller, action)
  type_colors = ["#7192DF", "#9DB1DF"]
  exp_colors = ["#65E2A2", "#97E2BC"]
  condition_colors = ["#D1F56E", "#E0F5A4"]
  controller_colors = ["#8D9280", "#F2F7E4"]
  action_colors = ["#ffffff", "#ffffff"]

  type_node = graph.add_child(type, type_colors, true)
  exp_node = type_node.add_child(exp, exp_colors, false)

  current_node = exp_node
  conditions.each do |c|
    current_node.add_child(c, condition_colors, true)
  end

  current_node.add_child(controller, controller_colors, true).add_child(action, action_colors, true)
end


def add_node_2(graph, type, exp, conditions, controller, action)
  type_colors = ["#7192DF", "#9DB1DF"]
  exp_colors = ["#65E2A2", "#97E2BC"]
  condition_colors = ["#D1F56E", "#E0F5A4"]
  controller_colors = ["#8D9280", "#F2F7E4"]
  action_colors = ["#ffffff", "#ffffff"]

  action_node = graph.add_child(controller, controller_colors, true).add_child(action, action_colors, true)

  type_node = action_node.add_child(type, type_colors, true)
  exp_node = type_node.add_child(exp, exp_colors, true)

  current_node = exp_node
  conditions.each do |c|
    current_node = current_node.add_child(c, condition_colors, true)
  end
end


def add_node_4(graph, type, exp, conditions, controller, action)
  type_colors = ["#7192DF", "#9DB1DF"]
  exp_colors = ["#65E2A2", "#97E2BC"]
  condition_colors = ["#D1F56E", "#E0F5A4"]
  controller_colors = ["#8D9280", "#F2F7E4"]
  action_colors = ["#ffffff", "#ffffff"]

  type_node = graph.add_child(type)
  exp_node = type_node.add_child(exp)
  exp_node.open(false)

  exp_node.add_child(controller.to_s + " / " + action.to_s, conditions)
end



class Graph
  def initialize(data, colors=["#c6dbef","#3182bd"], open=true)
    @data = data
    @children = []
    @colors = colors
    @open = open
  end

  def open(o)
    @open = o
  end

  def data
    @data
  end

  def add_child(data, colors=["#c6dbef", "#c6dbef"], open=false)
    if data.is_a? Array then
      val = "[" + data.map{|x| "\"" + x.to_s.gsub("\"", "\'").delete("\n") + "\""}.join(", ") + "]"
    else
      val = "\"" + data.to_s.gsub("\"", "\'").delete("\n") + "\""
    end

    existing = @children.select{|c| c.data == val}

    if existing != [] then
      existing.first
    else 
      child = Graph.new(val, colors, open)
      @children << child
      child
    end
  end

  def children
    @children
  end

  def to_json
    if @children == [] then
      "{\"name\": " + JSON.generate(@data.to_s, quirks_mode: true) + ", \"open_color\": \"" + @colors[0] + "\", \"closed_color\": \"" + @colors[1] + "\"}\n"
    else
      "{\"name\": " + JSON.generate(@data.to_s, quirks_mode: true) + ",\n" +
        "\"open_color\": \"" + @colors[0] + "\", \"closed_color\": \"" + @colors[1] + "\"," +
        if @open then "\"children\": [\n" else "\"_children\": [\n" end +
        @children.map{|v| v.to_json}.join(",\n") +
        "]}\n"
    end
  end

  def to_flare
    if @children == [] then
      "{\"name\": " + @data.to_s + ", \"open_color\": \"" + @colors[0] + "\", \"closed_color\": \"" + @colors[1] + "\", \"size\": 1}\n"
    else
      "{\"name\": " + @data.to_s + ",\n" +
        "\"open_color\": \"" + @colors[0] + "\", \"closed_color\": \"" + @colors[1] + "\"," +
        if @open then "\"children\": [\n" else "\"_children\": [\n" end +
        @children.map{|v| v.to_flare}.join(",\n") +
        "]}\n"
    end
  end

  def to_bubble
    if @children == [] then
      "{\"label\": \"" + @data.to_s + "\", \"amount\": 1}\n"
    else
      "{\"label\": \"" + @data.to_s + "\", \"amount\":" + @children.length.to_s + ",\n" +
        "\"children\": [\n" +
        @children.map{|v| v.to_bubble}.join(",\n") +
        "]}\n"
    end
  end

  def depth
    if @children == [] then
      1
    else
      1 + @children.map{|x| x.depth}.max
    end
  end

  def mk_s n
    if @children == [] then
      self.data.to_s
    else
      self.data.to_s + "\n" +
        @children.map{|x| (" " * n) + " |-  " + x.mk_s(n+1)}.join("\n")
    end
  end

  def to_s
    mk_s 1
  end
end


def sets_equal(s1, s2)
  result = true

  s1.each do |m|
    if !(s2.any?{|n| n == m}) then result = false end
  end

  s2.each do |m|
    if !(s1.any?{|n| n == m}) then result = false end
  end

  return result
end

class ConstraintGraph < Graph
  def initialize(data, constraints=[])
    super(data)
    @constraints = constraints
  end

  def set_constraints(constraints)
    @constraints = constraints
  end

  def constraints
    @constraints
  end

  def add_child(data, constraints=[])
    if data.is_a? Array then
      val = "[" + data.map{|x| x.to_s.gsub("\"", "\'").delete("\n")}.join(", ") + "]"
    else
      val = data.to_s.gsub("\"", "\'").delete("\n")
    end

    sym_ex = $symbolic_execution
    $symbolic_execution = false
    existing = @children.select{|c| c.data == val}

    test_val = existing != [] && sets_equal(existing.first.constraints, constraints)
    
    $symbolic_execution = sym_ex
    
    if test_val then
      #existing.first.set_constraints(constraints)
      existing.first
    else 
      child = ConstraintGraph.new(val, constraints)
      @children << child
      child
    end
  end

  def to_flare
    if @children == [] then
      if @constraints != [] then
        #cs = @constraints.join(", ")
        cs = @constraints.map{|x| JSON.generate(x, quirks_mode: true)}.join(", ")
        "{\"name\": " + JSON.generate(@data.to_s, quirks_mode: true) + 
          ", \"constraints\": [" + cs + "], \"size\": 1}\n"
      else
        "{\"name\": " + JSON.generate(@data.to_s, quirks_mode: true) + ", \"size\": 1}\n"
      end
    else
      "{\"name\": " + JSON.generate(@data.to_s, quirks_mode: true) + ",\n" +
        if @open then "\"children\": [\n" else "\"_children\": [\n" end +
        @children.map{|v| v.to_flare}.join(",\n") +
        "]}\n"
    end
  end

end


class Class
  def descendants
    result = []
    ObjectSpace.each_object(Class) { |klass| result << klass if klass < self }
    result
  end
end

$verification_conditions = []


class UnreachableException < Exception
end


class Symbol
  include Comparable

  def <=>(other)
    self.to_s <=> other.to_s
  end
end

class RubiconAnalysis
  def initialize(&block)
    @analysis_params = {
      :search_dirs => [],
      :extra_route_args => Hash.new,
      :routes => [],
      :routes_func => lambda { raise "error: no routes function provided" },
      :current_user_func => lambda { raise "error: no current user function provided" },
      :app_path => "no path provided",
      :policies => []
    }

    instance_eval &block

    Analyzer.new(@analysis_params).run_analysis
  end

  def be_displayed
    :be_displayed
  end

  def before(&block)
    @analysis_params[:before] = block
  end

  def to_get_routes(&block)
    @analysis_params[:routes_func] = block
  end

  def to_set_current_user(&block)
    @analysis_params[:current_user_func] = block
  end

  def extra_route_args(args)
    @analysis_params[:extra_route_args] = args
  end

  def search_dir(dir)
    @analysis_params[:search_dirs] << dir
  end

  def rails_path(path)
    @analysis_params[:app_path] = path
  end

  def check(&block)
    @analysis_params[:check] = block
  end

  def policies(&block)
    @analysis_params[:policies] = block
  end
end

class Analyzer
  def initialize(analysis_params)
    @analysis_params = analysis_params
    $analyzer = self
  end

  def run_analysis
    rails_path = @analysis_params[:app_path]
    $rails_path = rails_path

    ENV["RAILS_ENV"] ||= 'test'
    $VERBOSE = nil

    log "Loading rails files"
    # require 'rails'

    # log "Patching filters"
    # old_before_filter = ActionController::Base.method(:before_filter)
    # ActionController::Base.metaclass.send(:define_method, :before_filter, lambda{|*args| 
    #                                         log "HOHO " + args.to_s
    #                                         old_before_filter.call(*args)
    #                                       })

    require File.expand_path(rails_path.to_s + "/config/environment")

    log "Loading files from extra search directories"
    @analysis_params[:search_dirs].each do |dir|    
      Dir.glob(dir + '/*.rb').each { |file| require file }
    end

#    Rails.application.eager_load!

    def my_load_file(file)
      log "Loading file " + file.to_s
      begin
        require file
      rescue Exception => e
        log "Error loading file " + file.to_s + ": " + e.to_s
      end
    end

    Dir.glob(Rails.root.to_s + '/app/models/**/*.rb').each { |file| my_load_file(file) }
    activerecord_klasses = ActiveRecord::Base.descendants

    Dir.glob(Rails.root.to_s + '/app/controllers/**/*.rb').each { |file| my_load_file(file) }
    controller_klasses = ActionController::Base.descendants

    #Dir.glob(Rails.root.to_s + '/app/helpers/**/*.rb').each { |file| my_load_file(file) }


    log "Done loading files."

    def get_instance_vars(binding)
      ivars = eval("self.instance_variables", binding).select{|x| !x.to_s.start_with? "@_"}
      Hash[ivars.map {|v| [v, eval("instance_variable_get(\"" + v.to_s + "\")", binding)]}]
    end

    def fix_bindings(before, after, binding, condition)
      # log "<p>FIXING ********************************************************************************</p>"
      # log "<p>before: " + before.to_s + "</p><br>"
      # log "<p>after: " + after.to_s + "</p><br>"
      # log "<p>binding: " + binding.to_s + "</p><br>"
      # log "<p>condition: " + condition.to_s + "</p><br><br>"
      # log "<p>DONE ********************************************************************************</p><br>"

      after.each_pair do |var, val|
        next unless val.is_a? Exp # TODO
#        log "VAL IS EXP; comparison: " + (before[var].equals val).to_s

        if !before[var] then
#          log "FOUND NO VALUE: " + val.to_s
          val.add_constraint(condition)
        elsif before[var].equals val then
          # nothing
        else
          #log "ADDING CHOICE: " + var.to_s + ", " + val.to_s + ", " + before[var].to_s
          #before[var].add_constraint(Exp.new(:bool, :not, condition))
          val.add_constraint(condition)

          $temp1 = before[var]
          $temp2 = val

          choice = eval("instance_variable_set(:" + var.to_s + ", Choice.new($temp1, $temp2))", binding)
#          log "CHOICE: " + choice.to_s

#          choice = eval("instance_variable_set(" + var.to_s + ", Choice.new)",
#                        binding)
          #log "FOUND DIFFERENCE " + var.to_s + " : " + before[var].to_s + ", " + val.to_s

          # RIGHT HERE IS WHERE WE NEED TO DO SOMETHING LEGIT!!!!!!!1
          #raise "ERROR: Not an addition!!"
          
          #val.add_constraint(condition)
        end
      end
    end


    def derailer_and_or(typ, lhs, rhs)
      lhs_result = lhs.call

      if lhs_result.is_a? Exp then
        rhs_result = rhs.call
        result = Exp.new(:bool, lhs_result, typ, rhs_result)
        puts "SRC RESULTING " + result.to_s
        result
      else # non-symbolic
        case typ
        when :or
            if lhs_result then lhs_result else rhs.call end
        when :and
            if lhs_result then rhs.call else false end
        end
      end
    end

    $conditions = []
    $ifs = 0
    log "Initializing keyword virtualizers"
    # ActionController::Base
    # controller_virtualizer = VirtualKeywords::Virtualizer.new(:for_subclasses_of => [ ActionView::Template, 
    #                                                                                  ActionView::CompiledTemplates, ActionView::Base])

    def derailer_if(condition, then_do, else_do)
      puts "IN IF now"
      $ifs = $ifs + 1
      redirect = false
      
      c = condition.call

      ivars_before = get_instance_vars(condition.binding)
#      log "BEFORE: " + ivars_before.to_s

      begin
        then_result = then_do.call
      rescue UnreachableException
        log "UNREACHABLE: first branch"
        redirect = Exp.new(:bool, :not, c)
      rescue Exception => e
        log "FAILURE: " + e.to_s
      end

      ivars_middle = get_instance_vars(condition.binding)
      fix_bindings(ivars_before, ivars_middle, condition.binding, c)

      begin
        else_result = else_do.call
      rescue UnreachableException
        log "UNREACHABLE: second branch"
        if redirect then
          raise UnreachableException
        else
          redirect = c
        end
      rescue Exception => e
        log "FAILURE: " + e.to_s
      end

      ivars_end = get_instance_vars(condition.binding)
      fix_bindings(ivars_middle, ivars_end, condition.binding, Exp.new(:bool, :not, c))

      if redirect then
        $path_constraints << redirect
        log "ADDING REDIRECT: " + redirect.to_s
        log "IVARS: " + ivars_end.to_s
        # ivars_end.each_pair do |var, val|
        #   if val.is_a? Exp then
        #     val.add_constraint(redirect)
        #   else
        #     log "IVAR is not an expression!"
        #   end
        # end
      end

      $conditions << c

      if then_result
        then_result = Exp.new(then_result.class.to_s, then_result) unless then_result.is_a? Exp
        then_result.add_constraint(c)
      end

      if else_result
        else_result = Exp.new(else_result.class.to_s, else_result) unless else_result.is_a? Exp
        else_result.add_constraint(Exp.new(:not, c))
      end

      #Exp.new(:if, c, then_result, else_result)
      log "RESULTS: " + then_result.to_s + ", " + else_result.to_s
      Choice.new(then_result, else_result)
    end


    log "Instrumenting Controller and Model code"

    controller_klasses = ActionController::Base.descendants
    extraneous_methods = ActionController::Base.methods
    extraneous_instance_methods = ActionController::Base.instance_methods    

    def instr_meth(klass, m)
      begin
        new_src = instr_src(klass.instance_method(m).source)
        #puts new_src
        klass.class_eval(new_src)
      rescue SyntaxError => se
        log "   Error: Failed to eval code for " + klass.to_s + "." + m.to_s
        log "    Code is: " + new_src.to_s
      rescue => msg  
        #log "    ERROR: Something went wrong ("+msg.to_s+")"  
        log "    ERROR: Failed to instrument " + klass.to_s + "." + m.to_s
      end 
    end

    controller_klasses.each do |klass|
      puts klass
      (klass.methods - extraneous_methods).each do |m|
        puts "  " + m.to_s
      end
      

      mod = klass._helpers
      mod.instance_methods.each do |m|
        puts m
        instr_meth(mod, m)
      end

      (klass.instance_methods(false) - extraneous_instance_methods).each do |m|
        puts "  " + m.to_s
        #puts klass.instance_method(m).source

        instr_meth(klass, m)
      end
    end

    log "Loading class redefinitions..."
    require File.expand_path(File.dirname(__FILE__) + '/class_redefinitions')
    require File.expand_path(File.dirname(__FILE__) + '/alloy_translation')

    log "done."


    # ********************************************************************************

    # structure to describe fields, and a global var to hold them
    $class_fields = Hash.new

    def add_class_field(klass, name, type)
      #puts "adding class field: " + klass.to_s + ", " + name.to_s + ", " + type.to_s
      #puts "type of class is : " + klass.class.to_s
      field = DerailerField.new(name, type)

      if $class_fields[klass] then
        $class_fields[klass] << field
      else
        $class_fields[klass] = [field]
      end
    end

    activerecord_methods = ActiveRecord::Base.methods
    activerecord_instance_methods = ActiveRecord::Base.instance_methods
    log "Redefining ActiveRecord Classes"
    activerecord_klasses.each do |klass|
      klass_name = klass.to_s
      klass_methods = klass.methods - activerecord_methods
      klass_instance_methods = klass.instance_methods - activerecord_instance_methods

      # log "working on class " + klass_name
      # log "methods: "

      # log "originally " + klass.methods.length.to_s + ", reduced to " + klass_methods.length.to_s
      # log "and " + klass.instance_methods.length.to_s + "instance methods, reduced to " + klass_instance_methods.length.to_s
      # klass_methods.each do |m|
      #   log "  " + m.to_s
      # end

      # build a structure describing all the fields and their types
      begin
        klass.columns.each do |column|
          add_class_field(klass_name, column.name, column.type)
        end
        
        klass.reflect_on_all_associations.each do |assoc|
          add_class_field(klass_name, assoc.name, assoc.name.to_s.singularize.capitalize)
        end
      rescue => msg  
        log "    ERROR: Something went wrong ("+msg.to_s+")"  
      end 
      
      # replace the class with an expression so that all calls to the class methods are expressions
      # log "replacing class definitions"
      new_klass = Exp.new(klass_name, klass_name)
      new_klass.send(:define_method, :controller_name, lambda { klass_name })

      klass_methods.each do |m|
        old_method = klass.method(m)
        new_klass.metaclass.send(:define_method, m, lambda{|*args|
                                   log "HOHA: " + m.to_s
                                   old_method.call(*args)
                                 })
      end

      klass_instance_methods.each do |m|
        old_method = klass.instance_method(m)
        new_klass.send(:define_method, m, lambda{|*args|
                                   log "HOHAE: " + m.to_s
                                   old_method.call(*args)
                                 })
      end


      # THIS IS FOR THE BIIIIIIIIIIIIG OVERSIGHT
      # an EXP needs to ask in method_missing:
      #  is this method defined in my "type"'s CLASS DEFN
      # and if so, run that instead of producing an exp
      # log "has photos_from? " + new_klass.respond_to?(:photos_from).to_s
      # log "has photos_from? in thingy " + klass_instance_methods.map{|x| x.to_s}.include?('photos_from').to_s

      #replace_defs(klass, new_klass)

      fst, snd = klass.to_s.split("::")
      if snd then
        fst.constantize.const_set(snd, new_klass)
      else
        Object.const_set(klass.to_s, new_klass)
      end
    end




    #special for bluecloth
    Object.const_set("BlueCloth", Exp.new(:bluecloth, :bluecloth))

    log "Running analysis..."

    if @analysis_params[:before] then @analysis_params[:before].call end
    require 'rspec/rails'

    def test_one_action(controller, action)
      log "Running " + controller.to_s + " / " + action.to_s

      $track_to_s = false
      $to_s_exps = []
      $callback_conditions = []
      $path_constraints = []
      $saves = []

      p = controller.new

      if p.method(action).arity != 0 then
        return Hash.new
      end

      # TODO: do we still need these?
      [:@_routes, :@_controller, :@_request, :@_response].each do |v|
        p.instance_variable_set(v, Exp.new(:unused, v))
      end

      request = ActionController::TestRequest.new
      request.metaclass.send(:define_method, :accept, proc { "text/html" })
      request.metaclass.send(:define_method, :formats, proc { [Mime::HTML] })
      env = SymbolicArray.new(:env)
      ActionController::TestRequest.send(:define_method, :env, proc { env })
      controller.send(:define_method, :request, proc {request})

      my_session = SymbolicArray.new(:session)
      controller.send(:define_method, :session, proc {my_session})

      # [:request].each do |v|
      #   controller.send(:define_method, v, proc {Exp.new(v, v)})
      # end
      
      current_user = Exp.new(:User, :current_user)
      @analysis_params[:current_user_func].call(current_user)
      # this is specific...
      controller.send(:define_method, :authenticate_user, proc { @user = current_user; @current_user = current_user })
      controller.send(:define_method, :user_signed_in?, proc { current_user.signed_in? })

      controller.send(:define_method, :current_user, proc { puts "setting current user" ; @current_user = current_user })
      p.instance_variable_set(:@current_user, current_user)

      my_params = SymbolicArray.new(:params)
      controller.send(:define_method, :params, proc {my_params})
      controller.send(:define_method, :action_name, proc {action.to_s.dup})
      controller.send(:define_method, :redirect_to, lambda {|*args| raise UnreachableException })
      controller.send(:define_method, :assert_is_devise_resource!, proc { log "Assertion..."})
      controller.send(:define_method, :assert_is_devise_resource!, proc { log "Assertion..."})

      # to make sure rendering runs in rails 4
      controller.send(:define_method, :performed?, proc { false })

      # todo: spec the rest of these
      if defined? CanCan then
        CanCan::ControllerResource.send(:define_method, :load_and_authorize_resource, 
                                        proc { log "LOADINGG";
                                          name = @controller.class.to_s.sub("Controller", "").singularize.downcase
                                          type = name.camelize.to_s.to_sym;
                                          result = Exp.new(type, type, :find, Exp.new(:params, :id));
                                          result.add_constraint(Exp.new(:bool, :CanCan_authorized))
                                          log "NAME " + "@" + name.to_s;
                                          log "OUTPUT " + result.to_s;
                                          @controller.instance_variable_set("@" + name.to_s, result) })
      end

      if defined? Webfinger then
        Webfinger.metaclass.send(:define_method, :in_background,
                       lambda {|*args|
                         nil #correct? 
                       })
      end

      ActionView::Helpers::UrlHelper.send(:define_method, :url_for,
                                          lambda{|*args|
                                            log "called url_for"
                                            ""
                                          })
      
      ActionView::Helpers::FormHelper.send(:define_method, :form_for,
                                          lambda{|*args|
                                            log "called form_for"
                                            ""
                                           })

      ActionView::Helpers::TextHelper.send(:define_method, :simple_format,
                                           lambda{|arg|
                                             log "called simple_format"
                                             arg.to_s # this will trigger inclusion if we're rendering
                                           })


      if defined? ClientSideValidations then
        ClientSideValidations::ActionView::Helpers::FormHelper.send(:define_method, :form_for,
                                                                    lambda{|*args|
                                                                      log "called form_for validator"
                                                                      ""
                                                                    })
      end


      ActionView::Helpers.send(:define_method, :raw, lambda{|arg|
                                 a = flatten_exp(arg)
                                 without_symbolic do
                                   puts "EEE " + a.uniq.to_s
                                   puts "EEE " + a.uniq{|a,b| a == b}.length.to_s 
                                 end
                                 log "called raw " + flatten_exp(arg).map{|x| x.type.to_s}.join(", ")
                                 arg })

      ActionView::Helpers.send(:define_method, :sanitize, lambda{|arg|
                                 log "called sanitize"
                                 arg })

      
      # ActionController::Base.metaclass.class_eval do
      #   def __run_callback(key, kind, object, &blk) #:nodoc:
      #     name = __callback_runner_name(key, kind)
      #     log "CALLBACK " + name.to_s + ", " + key.to_s + ", " + kind.to_s + ", " + object.to_s
      #     unless object.respond_to?(name, true)
      #       str = object.send("_#{kind}_callbacks").compile(key, object)
      #       class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
      #       def #{name}() #{str} end
      #         protected :#{name}
      #         RUBY_EVAL
      #     end
      #     result = object.send(name, &blk)
      #     log "CALLBACK RESULT: " + result.to_s
      #     $callback_conditions << result
      #     result
      #   end
      # end

      
      old_template_handler = ActionView::Template::Handlers::ERB.instance_method(:call)
      ActionView::Template::Handlers::ERB.send(:define_method, :call, lambda{|*args|
                                                 log "instrumenting template code"
                                                 src = old_template_handler.bind(self).call(*args)
                                                 instr_src(src)
                                               })

      old_render = controller.instance_method(:render_to_body)
      controller.send(:define_method, :render_to_body, lambda{|*args|
                        log "RENDERING"
                        $track_to_s = true
                        my_render = old_render.bind(self)
                        begin
                          my_render.call(*args)
                          log "  RENDERING SUCCESSFUL"
                        rescue Exception => e
                          log "  RENDERING EXCEPTION: " + e.to_s
                          #puts " TRACE"
                          #puts e.backtrace.join("\n")
                        end
                        $track_to_s = false
                      })

      # ActionView::Template.send(:define_method, :render, lambda{|*args|
      #                             log "CALLED THE NEW FUCKER!!!!!!!!!!!!!!"
      #                           })

      ActionController::Rendering.send(:define_method, :render, lambda{|*args|
                                         log "RENDERING NOT TO BODY"
                                         begin
                                           super(*args)
                                           self.content_type ||= Mime[lookup_context.rendered_format].to_s
                                           response_body
                                         rescue Exception => e
                                           log "FUCKER EXCEPTION: " + e.to_s
                                           ""
                                         end
                                       })

      # timezone hack
      ActiveSupport::TimeZone.metaclass.send(:define_method, :[], lambda{|*args| Exp.new(:TimeZone, :timezone_of, *args)})
      # wish I didn't have to...
      #Devise::Mapping.metaclass.send(:define_method, :find_scope!, lambda{|*args| Exp.new(:Scope, :scope_of, *args)})
      
      vars_before = p.instance_variables
      sym_ex = $symbolic_execution
      $symbolic_execution = true
      r = p.send(:process_action, action)
      $symbolic_execution = sym_ex
      puts "THE RESPONSE IS " + r.class.to_s

      vars_after = p.instance_variables

      assign_vars = vars_after.select{|x| ! x.to_s.start_with? "@_"}
      assign_vals = assign_vars.map{|v| p.instance_variable_get(v)}



      $to_s_exps.each do |e|
          if e.is_a? Exp then
            $path_constraints.each do |c|
              e.add_constraint(c)
            end
            # $callback_conditions.each do |c|
            #   e.add_constraint(c)
            # end
          end
      end

      def flatten_choice(c)
        if c.is_a? Choice then
          flatten_choice(c.left) + flatten_choice(c.right)
        else
          [c]
        end
      end
      
      $to_s_exps = $to_s_exps.map{|e| flatten_exp(e)}.flatten(1)
      $to_s_exps.each do |e|
        consolidate_constraints(e)
      end

      $saves = $saves.map{|e| flatten_exp(e)}.flatten(1)
      $saves.each do |e|
        consolidate_constraints(e)
        puts "save is " + e.to_s + " and its updates are " + e.updates.to_s
      end

      [$to_s_exps, $saves]
    end

    results = Hash.new
    saves = Hash.new
    controller_klasses = ActionController::Base.descendants
    controller_klasses = [NotesController] # remove
    log "here are the controllers and their actions that I know of"

    controller_klasses.each do |c|
      log " "
      log c
      log c.action_methods.map{|x| x.to_s}.join(", ")
    end
      
    controller_klasses.each do |controller|
      controller.action_methods.each do |action|

        next unless action.to_s == "show" # remove
        
        puts "EEE " + action.to_s
        begin
          log "START"
          assign_vals, assign_saves = test_one_action(controller, action)
          results[controller.to_s + "/" + action.to_s] = assign_vals if assign_vals != []
          saves[controller.to_s + "/" + action.to_s] = assign_saves if assign_saves != []
        rescue UnreachableException => e
          log "UNREACHABLE"
          # unreachable...do nothing
        rescue Exception => e
          log "ERROR: couldn't do this one: " + e.to_s
          e.backtrace.each do |line|
            puts "ERROR: " + line.to_s
          end
        end
      end
    end

    log "done ********************************************************************************"

    e1 = Exp.new(1,2)
    e2 = Exp.new(3,4)

    log 'First: ' + (e1 == e2).to_s
    Exp.send(:define_method, :==, lambda{|x| equals(x)})
    log 'Second: ' + (e1 == e2).to_s

    graph = Graph.new("ActiveRecord", colors=["#536F05", "#536F05"])
    graph2 = Graph.new("ActionController", colors=["#536F05", "#536F05"])
    graph3 = Graph.new("ActiveRecord", colors=["#536F05", "#536F05"])
    graph4 = ConstraintGraph.new("ActiveRecord")

    results.each_pair do |controller_action, values|
      controller, action = controller_action.split("/")
      trans_vc = []

      values.each do |v|
        begin
          translated = v.to_alloy
          constraints = v.constraints.map{|c| c.to_alloy}
          add_node(graph, v.type.to_s, translated, constraints, controller, action)
          add_node_2(graph2, v.type.to_s, translated, constraints, controller, action)
          add_node_3(graph3, v.type.to_s, translated, constraints, controller, action)
          add_node_4(graph4, v.type.to_s, translated, constraints, controller, action)
        rescue => msg
          log "ERROR: couldn't translate " + v.to_s
          log "problem: " + msg.to_s
        end
      end
    end


    saves_graph = ConstraintGraph.new("ActiveRecord")
    saves.each_pair do |controller_action, values|
      next if values == nil
      controller, action = controller_action.split("/")
      trans_vc = []

      values.each do |v|
        begin
          translated = v.to_alloy
          constraints = v.constraints.map{|c| c.to_alloy}
          puts "v is " + v.to_s + " and it supdates are " + v.updates.to_s
          updates = "(" + v.updates.map{|x| x.to_alloy}.join(", ") + ")"
          add_node_4(saves_graph, v.type.to_s, translated + updates, constraints, controller, action)
        rescue => msg
          log "ERROR: couldn't translate " + v.to_s
          log "problem: " + msg.to_s
        end
      end
    end
    

    # log "CONDITIONS ********************************************************************************"

    # $conditions.each do |c|
    #   log " " + c.to_alloy.to_s
    # end

    # log "DONE ********************************************************************************"

    
    File.open(File.expand_path(File.dirname(__FILE__) + '/viz/graph.json'), 'w') do |file| 
      file.write graph.to_json
    end

    File.open(File.expand_path(File.dirname(__FILE__) + '/viz/graph2.json'), 'w') do |file| 
      file.write graph2.to_json
    end


    File.open(File.expand_path(File.dirname(__FILE__) + '/viz/constraint_graph.json'), 'w') do |file| 
      file.write graph4.to_flare
    end

    log graph4.to_s


    File.open(File.expand_path(File.dirname(__FILE__) + '/viz/saves.json'), 'w') do |file| 
      file.write saves_graph.to_flare
    end

    log ''
    log "Graph depth: " + graph.depth.to_s
    log "Used " + $ifs.to_s + " ifs"

    log ''

    # try to make some interesting results
    exps = results.values.flatten(1).select{|e| e.is_a? Exp}
    sorted_exps = exps.sort{|a,b| b.constraints.length <=> a.constraints.length}

    condition_set = Set.new
    total_conditions = 0
    sorted_exps.each do |e|
      total_conditions += e.constraints.length
      condition_set = condition_set + e.constraints
    end

    log 'Total condition instances: ' + total_conditions.to_s
    log 'Total unique conditions: ' + condition_set.length.to_s

    # log 'Trying the big thing:'
    # big_thing = condition_set.to_a.combination(5)
    # log 'Done'
    # n = 0
    # big_thing.each do |t|
    #   n += 1
    # end
    # log 'Done doing: ' + n.to_s

    def num_shared(a,b)
      (a.constraints & b.constraints).length
    end

    def add_some_nodes(graph, exps)
      if exps == [] then
        # done
      else
        first_exp, *rest_exps = exps.sort{|a,b| b.constraints.length <=> a.constraints.length}
        if first_exp.constraints == [] then
          # no constraints left...ALL exps must have none left
          ([first_exp] + rest_exps).each do |e|
            graph.add_child(e.to_alloy)
          end
        else
          working_set = first_exp.constraints
          final_set = working_set

          grouped_exps = [first_exp]
        
          while working_set.length >= 5 and rest_exps != [] do
            final_set = working_set
            first_exp, *rest_exps = rest_exps
            grouped_exps << first_exp
            working_set = working_set & first_exp.constraints
          end

          grouped_exps.each do |e|
            e.remove_constraints(final_set)
          end

          new_node = graph.add_child(final_set.map{|x| x.to_alloy})
          add_some_nodes(new_node, grouped_exps)
          add_some_nodes(graph, rest_exps) # we might be missing one exp in the middle
        end
      end
    end




    # ng = Graph.new("\"\"")
    # add_some_nodes(ng, exps)

    # log ng.to_s

    # File.open(File.expand_path(File.dirname(__FILE__) + '/viz/bubble.json'), 'w') do |file| 
    #   file.write ng.to_bubble
    # end

    # File.open(File.expand_path(File.dirname(__FILE__) + '/viz/flare.json'), 'w') do |file| 
    #   file.write ng.to_flare
    # end

    File.open(File.expand_path(File.dirname(__FILE__) + '/viz/flare2.json'), 'w') do |file| 
      file.write graph.to_flare
    end

    log 'Starting with ' + exps.length.to_s + ' exps'
    #log 'Starting with ' + final.length.to_s + ' constraints'
    # rest_exps.each do |e|
    #   final = final & e.constraints
    # end

    # log 'Finished with ' + final.length.to_s + ' constraints:'
    # log final.inspect

    # (1..final.length).each do |n|
    #   r = rest_exps.select{|e| num_shared(first_exp, e) >= n}
    #   log 'There are ' + r.length.to_s + ' exps that share ' + n.to_s + ' constraints with max'
    # end

    log ''


    results.each_pair do |controller_action, values|
      controller, action = controller_action.split("/")
      puts "NUM: " + values.length.to_s

      values.uniq.each do |v|
        
        translated = v.to_alloy
        next unless translated == "{ note : Note | note.id in params[id] }.content"
        constraints = v.constraints.map{|c| c.to_alloy}
        puts translated.to_s
        puts controller_action
        constraints.each do |c|
          puts "   " + c.to_s
        end
        puts ""
        
        v.constraints.each do |c|
          puts c.produce_write_constraint
        end
      end
    end


    
    # wtf ruby
    $graph = graph

    def start_web_server
      log "Starting web server..."
      log "When it's done, please browse to http://localhost:8000"
      log ""

      require 'webrick'
      root = File.expand_path(File.dirname(__FILE__) + '/viz/')
      cb = lambda do |req, res| 
        req.query[:graph_string] = $graph.to_s
        req.query[:rails_root] = Rails.root.to_s
        req.query[:log] = $log
      end

      WEBrick::HTTPUtils::DefaultMimeTypes['rhtml'] = 'text/html'
      server = WEBrick::HTTPServer.new :Port => 8001, :DocumentRoot => root, :RequestCallback => cb

      trap 'INT' do server.shutdown end

      server.start
    end
    
    start_web_server
    log ""
    log "All done!"
  end
end

