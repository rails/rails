module ActionController
  # Rewrites URLs for Base.redirect_to and Base.url_for in the controller.

  class UrlRewriter #:nodoc:
    RESERVED_OPTIONS = [:anchor, :params, :only_path, :host, :protocol, :trailing_slash, :skip_relative_url_root]
    def initialize(request, parameters)
      @request, @parameters = request, parameters
    end
    
    def rewrite(options = {})      
      rewrite_url(rewrite_path(options), options)
    end

    def to_str
      "#{@request.protocol}, #{@request.host_with_port}, #{@request.path}, #{@parameters[:controller]}, #{@parameters[:action]}, #{@request.parameters.inspect}"
    end

    alias_method :to_s, :to_str

    private
      def rewrite_url(path, options)
        rewritten_url = ""
        unless options[:only_path]
          rewritten_url << (options[:protocol] || @request.protocol)
          rewritten_url << (options[:host] || @request.host_with_port)
        end

        rewritten_url << @request.relative_url_root.to_s unless options[:skip_relative_url_root]
        rewritten_url << path
        rewritten_url << '/' if options[:trailing_slash]
        rewritten_url << "##{options[:anchor]}" if options[:anchor]

        rewritten_url
      end

      def rewrite_path(options)
        options = options.symbolize_keys
        options.update(options[:params].symbolize_keys) if options[:params]
        if (overwrite = options.delete(:overwrite_params))
          options.update(@parameters.symbolize_keys)
          options.update(overwrite)
        end
        RESERVED_OPTIONS.each {|k| options.delete k}
        path, extra_keys = Routing::Routes.generate(options.dup, @request) # Warning: Routes will mutate and violate the options hash

        path << build_query_string(options, extra_keys) unless extra_keys.empty?
        
        path
      end

      # Returns a query string with escaped keys and values from the passed hash. If the passed hash contains an "id" it'll
      # be added as a path element instead of a regular parameter pair.
      def build_query_string(hash, only_keys = nil)
        elements = []
        query_string = ""

        only_keys ||= hash.keys
        
        only_keys.each do |key|
          value = hash[key] 
          key = CGI.escape key.to_s
          if value.class == Array
            key <<  '[]'
          else
            value = [ value ]
          end
          value.each { |val| elements << "#{key}=#{Routing.extract_parameter_value(val)}" }
        end
        
        query_string << ("?" + elements.join("&")) unless elements.empty?
        query_string
      end
  end
end
