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
  module UrlWriter
    # The default options for urls written by this writer. Typically a :host pair
    # is provided.
    mattr_accessor :default_url_options
    self.default_url_options = {}
    
    def self.included(base) #:nodoc:
      ActionController::Routing::Routes.install_helpers base
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
    def url_for(options)
      options = self.class.default_url_options.merge(options)
      
      url = ''

      unless options.delete :only_path
        url << (options.delete(:protocol) || 'http')
        url << '://' unless url.match("://") #dont add separator if its already been specified in :protocol 
        
        raise "Missing host to link to! Please provide :host parameter or set default_url_options[:host]" unless options[:host]

        url << options.delete(:host)
        url << ":#{options.delete(:port)}" if options.key?(:port)
      else
        # Delete the unused options to prevent their appearance in the query string
        [:protocol, :host, :port].each { |k| options.delete k }
      end

      anchor = "##{CGI.escape options.delete(:anchor).to_param.to_s}" if options.key?(:anchor)
      url << Routing::Routes.generate(options, {})
      url << anchor if anchor

      return url
    end    
  end
  
  # Rewrites URLs for Base.redirect_to and Base.url_for in the controller.
  class UrlRewriter #:nodoc:
    RESERVED_OPTIONS = [:anchor, :params, :only_path, :host, :protocol, :port, :trailing_slash, :skip_relative_url_root]
    def initialize(request, parameters)
      @request, @parameters = request, parameters
    end
    
    def rewrite(options = {})
      rewrite_url(options)
    end

    def to_str
      "#{@request.protocol}, #{@request.host_with_port}, #{@request.path}, #{@parameters[:controller]}, #{@parameters[:action]}, #{@request.parameters.inspect}"
    end

    alias_method :to_s, :to_str

    private
      # Given a path and options, returns a rewritten URL string
      def rewrite_url(options)
        rewritten_url = ""

        unless options[:only_path]
          rewritten_url << (options[:protocol] || @request.protocol)
          rewritten_url << "://" unless rewritten_url.match("://")
          rewritten_url << rewrite_authentication(options)
          rewritten_url << (options[:host] || @request.host_with_port)
          rewritten_url << ":#{options.delete(:port)}" if options.key?(:port)
        end

        rewritten_url << @request.relative_url_root.to_s unless options[:skip_relative_url_root]
        rewritten_url << rewrite_path(options)
        rewritten_url << '/' if options[:trailing_slash]
        rewritten_url << "##{options[:anchor]}" if options[:anchor]

        rewritten_url
      end

      # Given a Hash of options, generates a route
      def rewrite_path(options)
        options = options.symbolize_keys
        options.update(options[:params].symbolize_keys) if options[:params]

        if (overwrite = options.delete(:overwrite_params))
          options.update(@parameters.symbolize_keys)
          options.update(overwrite.symbolize_keys)
        end

        RESERVED_OPTIONS.each { |k| options.delete(k) }

        # Generates the query string, too
        Routing::Routes.generate(options, @request.symbolized_path_parameters)
      end
      
      def rewrite_authentication(options)
        if options[:user] && options[:password]
          "#{CGI.escape(options.delete(:user))}:#{CGI.escape(options.delete(:password))}@"
        else
          ""
        end
      end
  end
end