module ActionController
  # Rewrites URLs for Base.redirect_to and Base.url_for in the controller.

  class UrlRewriter #:nodoc:
    RESERVED_OPTIONS = [:anchor, :params, :path_params, :only_path, :host, :protocol]
    def initialize(request, parameters)
      @request, @parameters = request, parameters
      @rewritten_path = @request.path ? @request.path.dup : ""
    end
    
    def rewrite(options = {})
      rewrite_url(rewrite_path(options), options)
    end

    def to_str
  		"#{@request.protocol}, #{@request.host_with_port}, #{@request.path}, #{@parameters[:controller]}, #{@parameters[:action]}, #{@request.parameters.inspect}"
    end

    alias_method :to_s, :to_str

    private
      def validate_options(valid_option_keys, supplied_option_keys)
        unknown_option_keys = supplied_option_keys - valid_option_keys
        raise(ActionController::ActionControllerError, "Unknown options: #{unknown_option_keys}") unless unknown_option_keys.empty?
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

      def rewrite_path(options)
        options = options.symbolize_keys
        RESERVED_OPTIONS.each {|k| options.delete k}
        
        path, extras = Routing::Routes.generate(options, @request)
        path = "/#{path.join('/')}"
        path += build_query_string(extras)
        
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
          key = key.to_s
          key = CGI.escape key
          key += '[]' if value.class == Array
          value = [ value ] unless value.class == Array
          value.each { |val| elements << "#{key}=#{CGI.escape(val.to_s)}" }
        end
        
        query_string << ("?" + elements.join("&")) unless elements.empty?
        return query_string
      end
  end
end