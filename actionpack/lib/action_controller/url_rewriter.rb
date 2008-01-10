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
      ActionController::Routing::Routes.install_helpers(base)
      base.mattr_accessor :default_url_options
      base.default_url_options ||= default_url_options
    end

    # Generate a url based on the options provided, default_url_options and the
    # routes defined in routes.rb.  The following options are supported:
    #
    # * <tt>:only_path</tt> If true, the relative url is returned. Defaults to false.
    # * <tt>:protocol</tt> The protocol to connect to. Defaults to 'http'.
    # * <tt>:host</tt> Specifies the host the link should be targetted at. If <tt>:only_path</tt> is false, this option must be
    #   provided either explicitly, or via default_url_options.
    # * <tt>:port</tt> Optionally specify the port to connect to.
    # * <tt>:anchor</tt> An anchor name to be appended to the path.
    # * <tt>:skip_relative_url_root</tt> If true, the url is not constructed using the relative_url_root set in <tt>ActionController::AbstractRequest.relative_url_root</tt>.
    #
    # Any other key(:controller, :action, etc...) given to <tt>url_for</tt> is forwarded to the Routes module.
    #
    # Examples:
    #
    #    url_for :controller => 'tasks', :action => 'testing', :host=>'somehost.org', :port=>'8080'    # => 'http://somehost.org:8080/tasks/testing'
    #    url_for :controller => 'tasks', :action => 'testing', :host=>'somehost.org', :anchor => 'ok', :only_path => true    # => '/tasks/testing#ok'
    #    url_for :controller => 'tasks', :action => 'testing', :host=>'somehost.org', :number => '33'  # => 'http://somehost.org/tasks/testing?number=33'
    def url_for(options)
      options = self.class.default_url_options.merge(options)

      url = ''

      unless options.delete(:only_path)
        url << (options.delete(:protocol) || 'http')
        url << '://' unless url.match("://")

        raise "Missing host to link to! Please provide :host parameter or set default_url_options[:host]" unless options[:host]

        url << options.delete(:host)
        url << ":#{options.delete(:port)}" if options.key?(:port)
      else
        # Delete the unused options to prevent their appearance in the query string.
        [:protocol, :host, :port, :skip_relative_url_root].each { |k| options.delete(k) }
      end

      url << ActionController::AbstractRequest.relative_url_root.to_s unless options[:skip_relative_url_root]
      anchor = "##{CGI.escape options.delete(:anchor).to_param.to_s}" if options[:anchor]
      url << Routing::Routes.generate(options, {})
      url << anchor if anchor

      url
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

        path = rewrite_path(options)
        rewritten_url << @request.relative_url_root.to_s unless options[:skip_relative_url_root]
        rewritten_url << (options[:trailing_slash] ? path.sub(/\?|\z/) { "/" + $& } : path)
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
