module ActionController
  # Rewrites urls for Base.redirect_to and Base.url_for in the controller.
  class UrlRewriter #:nodoc:
    VALID_OPTIONS = [:action, :action_prefix, :action_suffix, :application_prefix, :module, :controller, :controller_prefix, :anchor, :params, :path_params, :id, :only_path, :overwrite_params, :host, :protocol ]
  
    def initialize(request, controller, action)
      @request, @controller, @action = request, controller, action
      @rewritten_path = @request.path ? @request.path.dup : ""
    end
    
    def rewrite(options = {})
      validate_options(VALID_OPTIONS, options.keys)

      rewrite_url(
        rewrite_path(@rewritten_path, resolve_aliases(options)), 
        options
      )
    end

    def to_s
      to_str
    end

    def to_str
      "#{@request.protocol}, #{@request.host_with_port}, #{@request.path}, #{@controller}, #{@action}, #{@request.parameters.inspect}"
    end

    private
      def validate_options(valid_option_keys, supplied_option_keys)
        unknown_option_keys = supplied_option_keys - valid_option_keys
        raise(ActionController::ActionControllerError, "Unknown options: #{unknown_option_keys}") unless unknown_option_keys.empty?
      end
  
      def resolve_aliases(options)
        options[:controller_prefix] = options[:module] unless options[:module].nil?
        options
      end

      def rewrite_url(path, options)        
        rewritten_url = ""
        rewritten_url << (options[:protocol] || @request.protocol) unless options[:only_path]
        rewritten_url << (options[:host] || @request.host_with_port) unless options[:only_path]

	rewritten_url << options[:application_prefix] if options[:application_prefix]
        rewritten_url << path
        rewritten_url << build_query_string(new_parameters(options)) if options[:params] || options[:overwrite_params]
        rewritten_url << "##{options[:anchor]}" if options[:anchor]
        return rewritten_url
      end

      def rewrite_path(path, options)
        include_id_in_path_params(options)

        path = rewrite_action(path, options)      if options[:action] || options[:action_prefix]
        path = rewrite_path_params(path, options) if options[:path_params]
        path = rewrite_controller(path, options)  if options[:controller] || options[:controller_prefix]
        return path
      end

      def rewrite_path_params(path, options)
        index_action = options[:action] == 'index' || options[:action].nil? && @action == 'index'
        id_only = options[:path_params].size == 1 && options[:path_params]['id']

        if index_action && id_only
          path += '/' unless path[-1..-1] == '/'
          path += "index/#{options[:path_params]['id']}"
          path
        else
          options[:path_params].inject(path) do |path, pair|
            if options[:action].nil? && @request.parameters[pair.first]
              path.sub(/\b#{@request.parameters[pair.first]}\b/, pair.last.to_s)
            else
              path += "/#{pair.last}"
            end
          end
        end
      end

      def rewrite_action(path, options)
        # This regex assumes that "index" actions won't be included in the URL
        all, controller_prefix, action_prefix, action_suffix =
          /^\/(.*)#{@controller}\/(.*)#{@action == "index" ? "" : @action}(.*)/.match(path).to_a

        if @action == "index" 
          if action_prefix == "index" 
            # we broke the parsing assumption that this would be excluded, so
            # don't tell action_name about our little boo-boo
            path = path.sub(action_prefix, action_name(options, nil))
          elsif action_prefix && !action_prefix.empty?
            path = path.sub(%r(/#{action_prefix}/?), "/" + action_name(options, action_prefix))
          else
            path = path.sub(%r(#{@controller}/?$), @controller + "/" + action_name(options)) # " ruby-mode
          end
        else
          path = path.sub(
            @controller + "/" + (action_prefix || "") + @action + (action_suffix || ""), 
            @controller + "/" + action_name(options, action_prefix)
          )
        end

        if options[:controller_prefix] && !options[:controller]
          ensure_slash_suffix(options, :controller_prefix)
          if controller_prefix
            path = path.sub(controller_prefix, options[:controller_prefix])
          else
            path = options[:controller_prefix] + path
          end
        end
        
        return path
      end

      def rewrite_controller(path, options)
        all, controller_prefix = /^\/(.*?)#{@controller}/.match(path).to_a
        path = "/"
        path << controller_name(options, controller_prefix)
        path << action_name(options) if options[:action]
        path << path_params_in_list(options) if options[:path_params]
        return path
      end

      def action_name(options, action_prefix = nil, action_suffix = nil)
        ensure_slash_suffix(options, :action_prefix)
        ensure_slash_prefix(options, :action_suffix)

        prefix = options[:action_prefix] || action_prefix || ""
        suffix = options[:action] == "index" ? "" : (options[:action_suffix] || action_suffix || "")
        name   = (options[:action] == "index" ? "" : options[:action]) || ""

        return prefix + name + suffix
      end
      
      def controller_name(options, controller_prefix)
        ensure_slash_suffix(options, :controller_prefix)

        controller_name = case options[:controller_prefix]
          when String:  options[:controller_prefix]
          when false : ""
          when nil   : controller_prefix || ""
        end

        controller_name << (options[:controller] + "/") if options[:controller] 
        return controller_name
      end
      
      def path_params_in_list(options)
        options[:path_params].inject("") { |path, pair| path += "/#{pair.last}" }
      end

      def ensure_slash_suffix(options, key)
        options[key] = options[key] + "/" if options[key] && !options[key].empty? && options[key][-1..-1] != "/"
      end

      def ensure_slash_prefix(options, key)
        options[key] = "/" + options[key] if options[key] && !options[key].empty? && options[key][0..1] != "/"
      end

      def include_id_in_path_params(options)
        options[:path_params] = (options[:path_params] || {}).merge({"id" => options[:id]}) if options[:id]
      end

      def new_parameters(options)
        parameters = options[:params] || existing_parameters
        parameters.update(options[:overwrite_params]) if options[:overwrite_params]
        parameters.reject { |key,value| value.nil? }
      end

      def existing_parameters
        @request.parameters.reject { |key, value| %w( id action controller).include?(key) }
      end

      # Returns a query string with escaped keys and values from the passed hash. If the passed hash contains an "id" it'll
      # be added as a path element instead of a regular parameter pair.
      def build_query_string(hash)
        elements = []
        query_string = ""

        hash.each do |key, value|
	  key = CGI.escape key
	  key += '[]' if value.class == Array
	  value = [ value ] unless value.class == Array
	  value.each { |val| elements << "#{key}=#{CGI.escape(val.to_s)}" }
	end
        unless elements.empty? then query_string << ("?" + elements.join("&")) end
        
        return query_string
      end
  end
end
