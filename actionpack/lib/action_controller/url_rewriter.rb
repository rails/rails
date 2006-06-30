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

        # Generates the query string, too
        Routing::Routes.generate(options, @request.symbolized_path_parameters)
      end
  end
end
