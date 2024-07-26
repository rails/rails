module ActionController
  # Rewrites urls for Base.redirect_to and Base.url_for in the controller.
  class UrlRewriter #:nodoc:
    VALID_OPTIONS = [:action, :action_prefix, :action_suffix, :controller, :controller_prefix, :anchor, :params, :path_params, :id]
  
    def initialize(protocol, host, port, path, controller, action, params)
      @protocol, @host, @port, @path, @controller, @action, @params = protocol, host, port.to_i, path, controller, action, params
      @rewritten_path = @path ? @path.dup : ""
    end
    
    def rewrite(options = {})
      validate_options(VALID_OPTIONS, options.keys)

      rewrite_url(
        rewrite_path(@path.dup, options), 
        options
      )
    end

    def to_str
      "#{@protocol}, #{@host}, #{@path}, #{@controller}, #{@action}, #{@params.inspect}"
    end

    private
      def validate_options(valid_option_keys, supplied_option_keys)
        unknown_option_keys = supplied_option_keys - valid_option_keys
        raise(ActionController::ActionControllerError, "Unknown options: #{unknown_option_keys}") unless unknown_option_keys.empty?
      end

      def rewrite_url(path, options)
        rewritten_url = ""
        rewritten_url << @protocol
        rewritten_url << @host
        rewritten_url << ":#{@port}" unless @port == 80
        rewritten_url << path
        rewritten_url << build_query_string(options[:params]) if options[:params]
        return rewritten_url
      end

      def rewrite_path(path, options)
        include_id_in_path_params(options)
      
        path = rewrite_action(path, options)      if options[:action]
        path = rewrite_path_params(path, options) if options[:path_params]
        path = rewrite_controller(path, options)  if options[:controller]
        path << "#" + options[:anchor] if options[:anchor]
        return path
      end
      
      def rewrite_path_params(path, options)
        options[:path_params].inject(path) do |path, pair|
          if @params[pair.first]
            path.sub(@params[pair.first], pair.last)
          else
            path += "/#{pair.last}"
          end
        end
      end

      def rewrite_action(path, options)
        all, controller_prefix, action_prefix, action_suffix = 
          /^\/(.*)#{@controller}\/(.*)#{@action == "index" ? "" : @action}(.*)/.match(path).to_a

        if @action == "index" && action_prefix && !action_prefix.empty?
          path = path.sub(action_prefix, action_name(options, action_prefix))
        elsif @action == "index"
          path = path.sub(/#{@controller}\//, @controller + "/" + action_name(options))
        else
          path = path.sub((action_prefix || "") + @action + (action_suffix || ""), action_name(options, action_prefix, action_suffix))
        end

        if options[:controller_prefix] && !options[:controller]
          ensure_slash_suffix(options, :controller_prefix)
          path = path.sub(controller_prefix, options[:controller_prefix]) 
        end
        
        return path
      end

      def rewrite_controller(path, options)
        all, controller_prefix = /^\/(.*)#{@controller}/.match(path).to_a
        path = "/"
        path << controller_name(options, controller_prefix)
        path << action_name(options) unless options[:action].nil?
        return path
      end

      def action_name(options, action_prefix = nil, action_suffix = nil)
        ensure_slash_suffix(options, :action_prefix)
        ensure_slash_prefix(options, :action_suffix)

        prefix = options[:action_prefix] || action_prefix || ""
        suffix = options[:action] == "index" ? "" : (options[:action_suffix] || action_suffix || "")
        name = options[:action] == "index" ? "" : options[:action]

        return prefix + name + suffix
      end
      
      def controller_name(options, controller_prefix)
        ensure_slash_suffix(options, :controller_prefix)
        prefix = options[:controller_prefix] || controller_prefix || ""
        prefix + options[:controller] + "/"
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

      # Returns a query string with escaped keys and values from the passed hash. If the passed hash contains an "id" it'll
      # be added as a path element instead of a regular parameter pair.
      def build_query_string(hash)
        elements = []

        query_string = hash["id"] ? "/#{hash["id"]}" : ""
        hash.delete("id") if hash["id"]

        hash.each { |key, value| elements << "#{CGI.escape(key)}=#{CGI.escape(value.to_s)}" }
        unless elements.empty? then query_string << ("?" + elements.join("&")) end
        
        return query_string
      end
  end
end
