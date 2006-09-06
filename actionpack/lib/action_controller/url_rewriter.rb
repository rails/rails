module ActionController
  
  # Write URLs from arbitrary places in your codebase, such as your mailers.
  # 
  # Example:
  # 
  #   class MyMailer
  #     include ActionController::UrlWriter
  #     default_url_options[:host] = 'www.basecamphq.com'
  #     
  #     def signup_url(token)
  #       url_for(:controller => 'signup', action => 'index', :token => token)
  #     end
  #  end
  # 
  # In addition to providing +url_for+, named routes are also accessible after
  # including UrlWriter.
  # 
  module UrlWriter
    
    # The default options for urls written by this writer. Typically a :host pair
    # is provided.
    mattr_accessor :default_url_options
    self.default_url_options = {}
    
    def self.included(base) #:nodoc:
      ActionController::Routing::Routes.named_routes.install base
      base.mattr_accessor :default_url_options
      base.default_url_options ||= default_url_options
    end
    
    # Generate a url with the provided options. The following special options may
    # effect the constructed url:
    # 
    #   * :host Specifies the host the link should be targetted at. This option
    #     must be provided either explicitly, or via default_url_options.
    #   * :protocol The protocol to connect to. Defaults to 'http'
    #   * :port Optionally specify the port to connect to.
    # 
    def url_for(options)
      options = self.class.default_url_options.merge(options)
      
      url = ''
      unless options.delete :only_path
        url << (options.delete(:protocol) || 'http')
        url << '://'
        
        raise "Missing host to link to! Please provide :host parameter or set default_url_options[:host]" unless options[:host]
        url << options.delete(:host)
        url << ":#{options.delete(:port)}" if options.key?(:port)
      else
        # Delete the unused options to prevent their appearance in the query string
        [:protocol, :host, :port].each { |k| options.delete k }
      end
      url << Routing::Routes.generate(options, {})
      return url
    end
    
  end
  
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
