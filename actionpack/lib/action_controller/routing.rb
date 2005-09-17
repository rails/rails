module ActionController
  module Routing #:nodoc:
    class << self
      def expiry_hash(options, recall)
        k = v = nil
        expire_on = {}
        options.each {|k, v| expire_on[k] = ((rcv = recall[k]) && (rcv != v))}
        expire_on
      end

      def extract_parameter_value(parameter) #:nodoc:
        CGI.escape((parameter.respond_to?(:to_param) ? parameter.to_param : parameter).to_s) 
      end
      def controller_relative_to(controller, previous)
        if controller.nil?           then previous
        elsif controller[0] == ?/    then controller[1..-1]
        elsif %r{^(.*)/} =~ previous then "#{$1}/#{controller}"
        else controller
        end
      end

      def treat_hash(hash, keys_to_delete = [])
        k = v = nil
        hash.each do |k, v|
          if v then hash[k] = (v.respond_to? :to_param) ? v.to_param.to_s : v.to_s
          else
            hash.delete k
            keys_to_delete << k
          end
        end
        hash
      end
      
      def test_condition(expression, condition)
        case condition
          when String then "(#{expression} == #{condition.inspect})"
          when Regexp then
            condition = Regexp.new("^#{condition.source}$") unless /^\^.*\$$/ =~ condition.source 
            "(#{condition.inspect} =~ #{expression})"
          when Array then
            conds = condition.collect do |condition|
              cond = test_condition(expression, condition)
              (cond[0, 1] == '(' && cond[-1, 1] == ')') ? cond : "(#{cond})"
            end
            "(#{conds.join(' || ')})"
          when true then expression
          when nil then "! #{expression}"
          else
            raise ArgumentError, "Valid criteria are strings, regular expressions, true, or nil"
        end
      end
    end

    class Component #:nodoc:
      def dynamic?()  false end
      def optional?() false end

      def key() nil end
  
      def self.new(string, *args)
        return super(string, *args) unless self == Component
        case string
          when ':controller' then ControllerComponent.new(:controller, *args)
          when /^:(\w+)$/    then DynamicComponent.new($1, *args)
          when /^\*(\w+)$/   then PathComponent.new($1, *args)
          else StaticComponent.new(string, *args)
        end
      end 
    end

    class StaticComponent < Component #:nodoc:
      attr_reader :value
  
      def initialize(value)
        @value = value
      end

      def write_recognition(g)
        g.if_next_matches(value) do |gp|
          gp.move_forward {|gpp| gpp.continue}
        end
      end

      def write_generation(g)
        g.add_segment(value) {|gp| gp.continue }
      end
    end

    class DynamicComponent < Component #:nodoc:
      attr_reader :key, :default
      attr_accessor :condition
  
      def dynamic?()  true      end
      def optional?() @optional end

      def default=(default)
        @optional = true
        @default = default
      end
    
      def initialize(key, options = {})
        @key = key.to_sym
        default, @condition = options[:default], options[:condition]
        self.default = default if options.key?(:default)
      end

      def default_check(g)
        presence = "#{g.hash_value(key, !! default)}"
        if default
           "!(#{presence} && #{g.hash_value(key, false)} != #{default.to_s.inspect})"
        else
          "! #{presence}"
        end
      end
  
      def write_generation(g)
        wrote_dropout = write_dropout_generation(g)
        write_continue_generation(g, wrote_dropout)
      end

      def write_dropout_generation(g)
        return false unless optional? && g.after.all? {|c| c.optional?}
    
        check = [default_check(g)]
        gp = g.dup # Use another generator to write the conditions after the first &&
        # We do this to ensure that the generator will not assume x_value is set. It will
        # not be set if it follows a false condition -- for example, false && (x = 2)
        
        check += gp.after.map {|c| c.default_check gp}
        gp.if(check.join(' && ')) { gp.finish } # If this condition is met, we stop here
        true 
      end

      def write_continue_generation(g, use_else)
        test  = Routing.test_condition(g.hash_value(key, true, default), condition || true)
        check = (use_else && condition.nil? && default) ? [:else] : [use_else ? :elsif : :if, test]
    
        g.send(*check) do |gp|
          gp.expire_for_keys(key) unless gp.after.empty?
          add_segments_to(gp) {|gpp| gpp.continue}
        end
      end

      def add_segments_to(g)
        g.add_segment(%(\#{CGI.escape(#{g.hash_value(key, true, default)})})) {|gp| yield gp}
      end
  
      def recognition_check(g)
        test_type = [true, nil].include?(condition) ? :presence : :constraint
    
        prefix = condition.is_a?(Regexp) ? "#{g.next_segment(true)} && " : ''
        check = prefix + Routing.test_condition(g.next_segment(true), condition || true)
    
        g.if(check) {|gp| yield gp, test_type}
      end
  
      def write_recognition(g)
        test_type = nil
        recognition_check(g) do |gp, test_type|
          assign_result(gp) {|gpp| gpp.continue}
        end
    
        if optional? && g.after.all? {|c| c.optional?}
          call = (test_type == :presence) ? [:else] : [:elsif, "! #{g.next_segment(true)}"]
       
          g.send(*call) do |gp|
            assign_default(gp)
            gp.after.each {|c| c.assign_default(gp)}
            gp.finish(false)
          end
        end
      end

      def assign_result(g, with_default = false)
        g.result key, "CGI.unescape(#{g.next_segment(true, with_default ? default : nil)})"
        g.move_forward {|gp| yield gp}
      end

      def assign_default(g)
        g.constant_result key, default unless default.nil?
      end
    end

    class ControllerComponent < DynamicComponent #:nodoc:
      def key() :controller end

      def add_segments_to(g)
        g.add_segment(%(\#{#{g.hash_value(key, true, default)}})) {|gp| yield gp}
      end
    
      def recognition_check(g)
        g << "controller_result = ::ActionController::Routing::ControllerComponent.traverse_to_controller(#{g.path_name}, #{g.index_name})" 
        g.if('controller_result') do |gp|
          gp << 'controller_value, segments_to_controller = controller_result'
          if condition
            gp << "controller_path = #{gp.path_name}[#{gp.index_name},segments_to_controller].join('/')"
            gp.if(Routing.test_condition("controller_path", condition)) do |gpp|
              gpp.move_forward('segments_to_controller') {|gppp| yield gppp, :constraint}
            end
          else
            gp.move_forward('segments_to_controller') {|gpp| yield gpp, :constraint}
          end
        end
      end

      def assign_result(g)
        g.result key, 'controller_value'
        yield g
      end

      def assign_default(g)
        ControllerComponent.assign_controller(g, default)
      end
  
      class << self
        def assign_controller(g, controller)
          expr = "::Controllers::#{controller.split('/').collect {|c| c.camelize}.join('::')}Controller"
          g.result :controller, expr, true
        end

        def traverse_to_controller(segments, start_at = 0)
          mod = ::Controllers
          length = segments.length
          index = start_at
          mod_name = controller_name = segment = nil
      
          while index < length
            return nil unless /^[A-Za-z][A-Za-z\d_]*$/ =~ (segment = segments[index])
            index += 1
        
            mod_name = segment.camelize
            controller_name = "#{mod_name}Controller"
        
            return eval("mod::#{controller_name}", nil, 'routing.rb', __LINE__), (index - start_at) if mod.const_available?(controller_name)
            return nil unless mod.const_available?(mod_name)
            mod = eval("mod::#{mod_name}", nil, 'routing.rb', __LINE__)
          end
        end
      end
    end

    class PathComponent < DynamicComponent #:nodoc:
      def optional?() true end
      def default()   []  end
      def condition() nil  end

      def default=(value)
        raise RoutingError, "All path components have an implicit default of []" unless value == []
      end
  
      def write_generation(g)
        raise RoutingError, 'Path components must occur last' unless g.after.empty?
        g.if("#{g.hash_value(key, true)} && ! #{g.hash_value(key, true)}.empty?") do
          g << "#{g.hash_value(key, true)} = #{g.hash_value(key, true)}.join('/') unless #{g.hash_value(key, true)}.is_a?(String)"
          g.add_segment("\#{CGI.escape_skipping_slashes(#{g.hash_value(key, true)})}") {|gp| gp.finish }
        end
        g.else { g.finish }
      end
  
      def write_recognition(g)
        raise RoutingError, "Path components must occur last" unless g.after.empty?
    
        start = g.index_name
        start = "(#{start})" unless /^\w+$/ =~ start
    
        value_expr = "#{g.path_name}[#{start}..-1] || []"
        g.result key, "ActionController::Routing::PathComponent::Result.new_escaped(#{value_expr})"
        g.finish(false)
      end
  
      class Result < ::Array #:nodoc:
        def to_s() join '/' end
        def self.new_escaped(strings)
          new strings.collect {|str| CGI.unescape str}
        end
      end
    end

    class Route #:nodoc:
      attr_accessor :components, :known
      attr_reader :path, :options, :keys, :defaults
  
      def initialize(path, options = {})
        @path, @options = path, options
    
        initialize_components path
        defaults, conditions = initialize_hashes options.dup
        @defaults = defaults.dup
        configure_components(defaults, conditions)
        add_default_requirements
        initialize_keys
      end
  
      def inspect
        "<#{self.class} #{path.inspect}, #{options.inspect[1..-1]}>"
      end
  
      def write_generation(generator = CodeGeneration::GenerationGenerator.new)
        generator.before, generator.current, generator.after = [], components.first, (components[1..-1] || [])

        if known.empty? then generator.go
        else
          # Alter the conditions to allow :action => 'index' to also catch :action => nil
          altered_known = known.collect do |k, v|
            if k == :action && v== 'index' then [k, [nil, 'index']]
            else [k, v]
            end
          end
          generator.if(generator.check_conditions(altered_known)) {|gp| gp.go }
        end
        
        generator
      end
  
      def write_recognition(generator = CodeGeneration::RecognitionGenerator.new)
        g = generator.dup
        g.share_locals_with generator
        g.before, g.current, g.after = [], components.first, (components[1..-1] || [])
    
        known.each do |key, value|
          if key == :controller then ControllerComponent.assign_controller(g, value)
          else g.constant_result(key, value)
          end
        end
    
        g.go
    
        generator
      end

      def initialize_keys
        @keys = (components.collect {|c| c.key} + known.keys).compact
        @keys.freeze
      end
  
      def extra_keys(options)
        options.keys - @keys
      end
    
      def matches_controller?(controller)
        if known[:controller] then known[:controller] == controller
        else
          c = components.find {|c| c.key == :controller}
          return false unless c
          return c.condition.nil? || eval(Routing.test_condition('controller', c.condition))
        end
      end
  
      protected
        def initialize_components(path)
          path = path.split('/') if path.is_a? String
          path.shift if path.first.blank?
          self.components = path.collect {|str| Component.new str}
        end
    
        def initialize_hashes(options)
          path_keys = components.collect {|c| c.key }.compact 
          self.known = {}
          defaults = options.delete(:defaults) || {}
          conditions = options.delete(:require) || {}
          conditions.update(options.delete(:requirements) || {})
      
          options.each do |k, v|
            if path_keys.include?(k) then (v.is_a?(Regexp) ? conditions : defaults)[k] = v
            else known[k] = v
            end
          end
          [defaults, conditions]
        end
    
        def configure_components(defaults, conditions)
          components.each do |component|
            if defaults.key?(component.key) then component.default = defaults[component.key]
            elsif component.key == :action  then component.default = 'index'
            elsif component.key == :id      then component.default = nil
            end
        
            component.condition = conditions[component.key] if conditions.key?(component.key)
          end
        end
        
        def add_default_requirements
          component_keys = components.collect {|c| c.key}
          known[:action] ||= 'index' unless component_keys.include? :action
        end
    end

    class RouteSet #:nodoc:
      attr_reader :routes, :categories, :controller_to_selector
      def initialize
        @routes = []
        @generation_methods = Hash.new(:generate_default_path)
      end
      
      def generate(options, request_or_recall_hash = {})
        recall = request_or_recall_hash.is_a?(Hash) ? request_or_recall_hash : request_or_recall_hash.symbolized_path_parameters
        use_recall = true
        
        controller = options[:controller]
        options[:action] ||= 'index' if controller
        recall_controller = recall[:controller]
        if (recall_controller && recall_controller.include?(?/)) || (controller && controller.include?(?/)) 
          recall = {} if controller && controller[0] == ?/
          options[:controller] = Routing.controller_relative_to(controller, recall_controller)
        end
        options = recall.dup if options.empty? # XXX move to url_rewriter?
        
        keys_to_delete = []
        Routing.treat_hash(options, keys_to_delete)
        
        merged = recall.merge(options)
        keys_to_delete.each {|key| merged.delete key}
        expire_on = Routing.expiry_hash(options, recall)
    
        generate_path(merged, options, expire_on)
      end
      
      def generate_path(merged, options, expire_on)
        send @generation_methods[merged[:controller]], merged, options, expire_on
      end
      def generate_default_path(*args)
        write_generation
        generate_default_path(*args)
      end
  
      def write_generation
        method_sources = []
        @generation_methods = Hash.new(:generate_default_path)
        categorize_routes.each do |controller, routes|
          next unless routes.length < @routes.length
      
          ivar = controller.gsub('/', '__')
          method_name = "generate_path_for_#{ivar}".to_sym
          instance_variable_set "@#{ivar}", routes
          code = generation_code_for(ivar, method_name).to_s
          method_sources << code
          
          filename = "generated_code/routing/generation_for_controller_#{controller}.rb"
          eval(code, nil, filename)
      
          @generation_methods[controller.to_s]   = method_name
          @generation_methods[controller.to_sym] = method_name
        end
        
        
        code = generation_code_for('routes', 'generate_default_path').to_s
        eval(code, nil, 'generated_code/routing/generation.rb')
        
        return (method_sources << code)
      end

      def recognize(request)
        string_path = request.path  
        string_path.chomp! if string_path[0] == ?/  
        path = string_path.split '/'  
        path.shift  
   
        hash = recognize_path(path)  
        return recognition_failed(request) unless hash && hash['controller']  
   
        controller = hash['controller']  
        hash['controller'] = controller.controller_path  
        request.path_parameters = hash  
        controller.new 
      end
      alias :recognize! :recognize
  
      def recognition_failed(request)
        raise ActionController::RoutingError, "Recognition failed for #{request.path.inspect}"
      end

      def write_recognition
        g = generator = CodeGeneration::RecognitionGenerator.new
        g.finish_statement = Proc.new {|hash_expr| "return #{hash_expr}"}
    
        g.def "self.recognize_path(path)" do
          each do |route|
            g << 'index = 0'
            route.write_recognition(g)
          end
        end
    
        eval g.to_s, nil, 'generated/routing/recognition.rb'
        return g.to_s
      end
        
      def generation_code_for(ivar = 'routes', method_name = nil)
        routes = instance_variable_get('@' + ivar)
        key_ivar = "@keys_for_#{ivar}"
        instance_variable_set(key_ivar, routes.collect {|route| route.keys})
    
        g = generator = CodeGeneration::GenerationGenerator.new
        g.def "self.#{method_name}(merged, options, expire_on)" do
          g << 'unused_count = options.length + 1'
          g << "unused_keys = keys = options.keys"
          g << 'path = nil'
      
          routes.each_with_index do |route, index|
            g << "new_unused_keys = keys - #{key_ivar}[#{index}]"
            g << 'new_path = ('
            g.source.indent do
              if index.zero?
                g << "new_unused_count = new_unused_keys.length"
                g << "hash = merged; not_expired = true"
                route.write_generation(g.dup)
              else
                g.if "(new_unused_count = new_unused_keys.length) < unused_count" do |gp|
                  gp << "hash = merged; not_expired = true"
                  route.write_generation(gp)
                end
              end
            end
            g.source.lines.last << ' )' # Add the closing brace to the end line
            g.if 'new_path' do
              g << 'return new_path, [] if new_unused_count.zero?'
              g << 'path = new_path; unused_keys = new_unused_keys; unused_count = new_unused_count'
            end
          end
        
          g << "raise RoutingError, \"No url can be generated for the hash \#{options.inspect}\" unless path"
          g << "return path, unused_keys"
        end
        
        return g
      end
      
      def categorize_routes
        @categorized_routes = by_controller = Hash.new(self)
      
        known_controllers.each do |name|
          set = by_controller[name] = []
          each do |route|
            set << route if route.matches_controller? name
          end
        end
    
        @categorized_routes
      end
      
      def known_controllers
        @routes.inject([]) do |known, route|
          if (controller = route.known[:controller])
            if controller.is_a?(Regexp)
              known << controller.source.scan(%r{[\w\d/]+}).select {|word| controller =~ word} 
            else known << controller
            end
          end
          known
        end.uniq
      end

      def reload
        NamedRoutes.clear
        
        if defined?(RAILS_ROOT) then load(File.join(RAILS_ROOT, 'config', 'routes.rb'))
        else connect(':controller/:action/:id', :action => 'index', :id => nil)
        end

        NamedRoutes.install
      end

      def connect(*args)
        new_route = Route.new(*args)
        @routes << new_route
        return new_route
      end

      def draw
        old_routes = @routes
        @routes = []
        
        begin yield self
        rescue
          @routes = old_routes
          raise
        end
        write_generation
        write_recognition
      end
      
      def empty?() @routes.empty? end
  
      def each(&block) @routes.each(&block) end
      
      # Defines a new named route with the provided name and arguments.
      # This method need only be used when you wish to use a name that a RouteSet instance
      # method exists for, such as categories.
      #
      # For example, map.categories '/categories', :controller => 'categories' will not work
      # due to RouteSet#categories.
      def named_route(name, path, hash = {})
        route = connect(path, hash)
        NamedRoutes.name_route(route, name)
        route
      end
      
      def method_missing(name, *args)
        (1..2).include?(args.length) ? named_route(name, *args) : super(name, *args)
      end

      def extra_keys(options, recall = {})
        generate(options.dup, recall).last
      end
    end

    module NamedRoutes #:nodoc:
      Helpers = []
      class << self
        def clear() Helpers.clear end
  
        def hash_access_name(name)
          "hash_for_#{name}_url"
        end

        def url_helper_name(name)
          "#{name}_url"
        end
        
        def known_hash_for_route(route)
          hash = route.known.symbolize_keys
          route.defaults.each do |key, value|
            hash[key.to_sym] ||= value if value
          end
          hash[:controller] = "/#{hash[:controller]}"
          
          hash
        end
        
        def define_hash_access_method(route, name)
          hash = known_hash_for_route(route)
          define_method(hash_access_name(name)) do |*args|
            args.first ? hash.merge(args.first) : hash
          end
        end
        
        def name_route(route, name)
          define_hash_access_method(route, name)
          
          module_eval(%{def #{url_helper_name name}(options = {})
            url_for(#{hash_access_name(name)}.merge(options))
          end}, "generated/routing/named_routes/#{name}.rb")
      
          protected url_helper_name(name), hash_access_name(name)
      
          Helpers << url_helper_name(name).to_sym
          Helpers << hash_access_name(name).to_sym
          Helpers.uniq!
        end
    
        def install(cls = ActionController::Base)
          cls.send :include, self
          if cls.respond_to? :helper_method
            Helpers.each do |helper_name|
              cls.send :helper_method, helper_name
            end
          end
        end
      end
    end

    Routes = RouteSet.new
  end
end
