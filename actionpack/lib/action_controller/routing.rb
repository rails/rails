module ActionController
  # See http://manuals.rubyonrails.com/read/chapter/65
  module Routing
    ROUTE_FILE = defined?(RAILS_ROOT) ? File.expand_path(File.join(RAILS_ROOT, 'config', 'routes')) : nil
  
    class Route #:nodoc:
      attr_reader :defaults # The defaults hash
      
      def initialize(path, hash={})
        raise ArgumentError, "Second argument must be a hash!" unless hash.kind_of?(Hash)
        @defaults = hash[:defaults].kind_of?(Hash) ? hash.delete(:defaults) : {}
        @requirements = hash[:requirements].kind_of?(Hash) ? hash.delete(:requirements) : {}
        self.items = path
        hash.each do |k, v|
          raise TypeError, "Hash keys must be symbols!" unless k.kind_of? Symbol
          if v.kind_of? Regexp
            raise ArgumentError, "Regexp requirement on #{k}, but #{k} is not in this route's path!" unless @items.include? k
            @requirements[k] = v
          else
            (@items.include?(k) ? @defaults : @requirements)[k] = v
          end
        end
        
        @defaults.each do |k, v|
          raise ArgumentError, "A default has been specified for #{k}, but #{k} is not in the path!" unless @items.include? k
          @defaults[k] = v.to_s unless v.kind_of?(String) || v.nil?
        end
        @requirements.each {|k, v| raise ArgumentError, "A Regexp requirement has been specified for #{k}, but #{k} is not in the path!" if v.kind_of?(Regexp) && ! @items.include?(k)}
        
        # Add in defaults for :action and :id.
        [[:action, 'index'], [:id, nil]].each do |name, default|
          @defaults[name] = default if @items.include?(name) && ! (@requirements.key?(name) || @defaults.key?(name))
        end
      end
      
      # Generate a URL given the provided options.
      # All values in options should be symbols.
      # Returns the path and the unused names in a 2 element array.
      # If generation fails, [nil, nil] is returned
      # Generation can fail because of a missing value, or because an equality check fails.
      #
      # Generate urls will be as short as possible. If the last component of a url is equal to the default value,
      # then that component is removed. This is applied as many times as possible. So, your index controller's
      # index action will generate []
      def generate(options, defaults={})
        non_matching = @requirements.keys.select {|name| ! passes_requirements?(name, options[name] || defaults[name])}
        non_matching.collect! {|name| requirements_for(name)}
        return nil, "Mismatching option#{'s' if non_matching.length > 1}:\n   #{non_matching.join '\n   '}" unless non_matching.empty?
        
        used_names = @requirements.inject({}) {|hash, (k, v)| hash[k] = true; hash} # Mark requirements as used so they don't get put in the query params
        components = @items.collect do |item|
          if item.kind_of? Symbol
            used_names[item] = true
            value = options[item] || defaults[item] || @defaults[item]
            return nil, requirements_for(item) unless passes_requirements?(item, value)
            defaults = {} unless defaults == {} || value == defaults[item] # Stop using defaults if this component isn't the same as the default.
            (value.nil? || item == :controller) ? value : CGI.escape(value.to_s)
          else item
          end
        end
        
        @items.reverse_each do |item| # Remove default components from the end of the generated url.
          break unless item.kind_of?(Symbol) && @defaults[item] == components.last
          components.pop
        end
        
        # If we have any nil components then we can't proceed.
        # This might need to be changed. In some cases we may be able to return all componets after nil as extras.
        missing = []; components.each_with_index {|c, i| missing << @items[i] if c.nil?}
        return nil, "No values provided for component#{'s' if missing.length > 1} #{missing.join ', '} but values are required due to use of later components" unless missing.empty? # how wide is your screen?
        
        unused = (options.keys - used_names.keys).inject({}) do |unused, key|
          unused[key] = options[key] if options[key] != @defaults[key]
          unused
        end
        
        components.collect! {|c| c.to_s}
        return components, unused
      end
      
      # Recognize the provided path, returning a hash of recognized values, or [nil, reason] if the path isn't recognized.
      # The path should be a list of component strings.
      # Options is a hash of the ?k=v pairs
      def recognize(components, options={})
        options = options.clone
        components = components.clone
        controller_class = nil
        
        @items.each do |item|
          if item == :controller # Special case for controller
            if components.empty? && @defaults[:controller]
              controller_class, leftover = eat_path_to_controller(@defaults[:controller].split('/'))
              raise RoutingError, "Default controller does not exist: #{@defaults[:controller]}" if controller_class.nil? || leftover.empty? == false
            else
              controller_class, remaining_components = eat_path_to_controller(components)
              return nil, "No controller found at subpath #{components.join('/')}" if controller_class.nil?
              components = remaining_components
            end
            options[:controller] = controller_class.controller_path
            return nil, requirements_for(:controller) unless passes_requirements?(:controller, options[:controller])
          elsif item.kind_of? Symbol
            value = components.shift || @defaults[item]
            return nil, requirements_for(item) unless passes_requirements?(item, value)
            options[item] = value.nil? ? value : CGI.unescape(value)
          else
            return nil, "No value available for component #{item.inspect}" if components.empty?
            component = components.shift
            return nil, "Value for component #{item.inspect} doesn't match #{component}" if component != item
          end
        end
        
        if controller_class.nil? && @requirements[:controller] # Load a default controller
          controller_class, extras = eat_path_to_controller(@requirements[:controller].split('/'))
          raise RoutingError, "Illegal controller path for route default: #{@requirements[:controller]}" unless controller_class && extras.empty?
          options[:controller] = controller_class.controller_path
        end
        @requirements.each {|k,v| options[k] ||= v unless v.kind_of?(Regexp)}

        return nil, "Route recognition didn't find a controller class!" unless controller_class
        return nil, "Unused components were left: #{components.join '/'}" unless components.empty?
        options.delete_if {|k, v| v.nil?} # Remove nil values.
        return controller_class, options
      end
      
      def inspect
        when_str = @requirements.empty? ? "" : " when #{@requirements.inspect}"
        default_str = @defaults.empty? ? "" : " || #{@defaults.inspect}"
        "<#{self.class.to_s} #{@items.collect{|c| c.kind_of?(String) ? c : c.inspect}.join('/').inspect}#{default_str}#{when_str}>"
      end
      
      protected
        # Find the controller given a list of path components.
        # Return the controller class and the unused path components.
        def eat_path_to_controller(path)
          path.inject([Controllers, 1]) do |(mod, length), name|
            name = name.camelize
            controller_name = name + "Controller"
            return mod.const_get(controller_name), path[length..-1] if mod.const_available? controller_name
            return nil, nil unless mod.const_available? name
            [mod.const_get(name), length + 1]
          end
          return nil, nil # Path ended, but no controller found.
        end
      
        def items=(path)
          items = path.split('/').collect {|c| (/^:(\w+)$/ =~ c) ? $1.intern : c} if path.kind_of?(String) # split and convert ':xyz' to symbols
          items.shift if items.first == ""
          items.pop if items.last == ""
          @items = items
          
          # Verify uniqueness of each component.
          @items.inject({}) do |seen, item|
            if item.kind_of? Symbol
              raise ArgumentError, "Illegal route path -- duplicate item #{item}\n   #{path.inspect}" if seen.key? item
              seen[item] = true
            end
            seen
          end
        end
        
        # Verify that the given value passes this route's requirements
        def passes_requirements?(name, value)
          return @defaults.key?(name) && @defaults[name].nil? if value.nil? # Make sure it's there if it should be
          
          case @requirements[name]
            when nil then true
            when Regexp then
              value = value.to_s
              match = @requirements[name].match(value)
              match && match[0].length == value.length
            else
              @requirements[name] == value.to_s
          end
        end
        def requirements_for(name)
          presence = (@defaults.key?(name) && @defaults[name].nil?)
          requirement = case @requirements[name]
            when nil then nil
            when Regexp then "match #{@requirements[name].inspect}"
            else "be equal to #{@requirements[name].inspect}"
          end
          if presence && requirement then "#{name} must be present and #{requirement}"
          elsif presence || requirement then "#{name} must #{requirement || 'be present'}"
          else "#{name} has no requirements"
          end
        end
    end
    
    class RouteSet#:nodoc:
      def initialize
        @routes = []
      end
      
      def add_route(route)
        raise TypeError, "#{route.inspect} is not a Route instance!" unless route.kind_of?(Route)
        @routes << route
      end
      def empty?
        @routes.empty?
      end
      def each
        @routes.each {|route| yield route}
      end
      
      # Generate a path for the provided options
      # Returns the path as an array of components and a hash of unused names
      # Raises RoutingError if not route can handle the provided components.
      #
      # Note that we don't return the first generated path. We do this so that when a route
      # generates a path from a subset of the available options we can keep looking for a 
      # route which can generate a path that uses more options.
      # Note that we *do* return immediately if 
      def generate(options, request)
        raise RoutingError, "There are no routes defined!" if @routes.empty?

        options = options.symbolize_keys
        defaults = request.path_parameters.symbolize_keys
        if options.empty? then options = defaults.clone # Get back the current url if no options was passed
        else expand_controller_path!(options, defaults) # Expand the supplied controller path.
        end
        defaults.delete_if {|k, v| options.key?(k) && options[k].nil?} # Remove defaults that have been manually cleared using :name => nil

        failures = []
        selected = nil
        self.each do |route|
          path, unused = route.generate(options, defaults)
          if path.nil?
            failures << [route, unused] if ActionController::Base.debug_routes
          else 
            return path, unused if unused.empty? # Found a perfect route -- we're finished.
            if selected.nil? || unused.length < selected.last.length
              failures << [selected.first, "A better url than #{selected[1]} was found."] if selected
              selected = [route, path, unused]
            end
          end
        end
        
        return selected[1..-1] unless selected.nil?
        raise RoutingError.new("Generation failure: No route for url_options #{options.inspect}, defaults: #{defaults.inspect}", failures)
      end
      
      # Recognize the provided path.
      # Raise RoutingError if the path can't be recognized.
      def recognize!(request)
        path = ((%r{^/?(.*)/?$} =~ request.path) ? $1 : request.path).split('/')
        raise RoutingError, "There are no routes defined!" if @routes.empty?
        
        failures = []
        self.each do |route|
          controller, options = route.recognize(path)
          if controller.nil?
            failures << [route, options] if ActionController::Base.debug_routes
          else
            request.path_parameters = options
            return controller
          end
        end
        
        raise RoutingError.new("No route for path: #{path.join('/').inspect}", failures)
      end
      
      def expand_controller_path!(options, defaults)
        if options[:controller]
          if /^\// =~ options[:controller]
            options[:controller] = options[:controller][1..-1]
            defaults.clear # Sending to absolute controller implies fresh defaults
          else
            relative_to = defaults[:controller] ? defaults[:controller].split('/')[0..-2].join('/') : ''
            options[:controller] = relative_to.empty? ? options[:controller] : "#{relative_to}/#{options[:controller]}"
            defaults.delete(:action) if options.key?(:controller)
          end
        else
          options[:controller] = defaults[:controller]
        end
      end
      
      def route(*args)
        add_route(Route.new(*args))
      end
      alias :connect :route
      
      def reload
        begin
          require_dependency(ROUTE_FILE) if ROUTE_FILE
        rescue LoadError, ScriptError => e
          raise RoutingError, "Cannot load config/routes.rb:\n    #{e.message}"
        ensure # Ensure that there is at least one route:
          connect(':controller/:action/:id', :action => 'index', :id => nil) if @routes.empty?
        end
      end
      
      def draw
        @routes.clear
        yield self
      end
    end
    
    def self.draw(*args, &block) #:nodoc:
      Routes.draw(*args) {|*args| block.call(*args)}
    end
    
    Routes = RouteSet.new
  end
end
