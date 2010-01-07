require 'active_support/core_ext/hash/except'

module ActionController
  # Rewrites URLs for Base.redirect_to and Base.url_for in the controller.
  class UrlRewriter #:nodoc:
    RESERVED_OPTIONS = [:anchor, :params, :only_path, :host, :protocol, :port, :trailing_slash, :skip_relative_url_root]

    def initialize(request, parameters)
      @request, @parameters = request, parameters
    end

    def rewrite(options = {})
      options[:host]     ||= @request.host_with_port
      options[:protocol] ||= @request.protocol

      self.class.rewrite(options, @request.symbolized_path_parameters) do |options|
        process_path_options(options)
      end
    end

    def to_str
      "#{@request.protocol}, #{@request.host_with_port}, #{@request.path}, #{@parameters[:controller]}, #{@parameters[:action]}, #{@request.parameters.inspect}"
    end

    alias_method :to_s, :to_str

    def self.rewrite(options, path_segments=nil)
      rewritten_url = ""

      unless options[:only_path]
        rewritten_url << (options[:protocol] || "http")
        rewritten_url << "://" unless rewritten_url.match("://")
        rewritten_url << rewrite_authentication(options)

        raise "Missing host to link to! Please provide :host parameter or set default_url_options[:host]" unless options[:host]

        rewritten_url << options[:host]
        rewritten_url << ":#{options.delete(:port)}" if options.key?(:port)
      end

      path_options = options.except(*RESERVED_OPTIONS)
      path_options = yield(path_options) if block_given?
      path = Routing::Routes.generate(path_options, path_segments || {})

      rewritten_url << ActionController::Base.relative_url_root.to_s unless options[:skip_relative_url_root]
      rewritten_url << (options[:trailing_slash] ? path.sub(/\?|\z/) { "/" + $& } : path)
      rewritten_url << "##{Rack::Utils.escape(options[:anchor].to_param.to_s)}" if options[:anchor]

      rewritten_url
    end

  protected

    def self.rewrite_authentication(options)
      if options[:user] && options[:password]
        "#{Rack::Utils.escape(options.delete(:user))}:#{Rack::Utils.escape(options.delete(:password))}@"
      else
        ""
      end
    end

    # Given a Hash of options, generates a route
    def process_path_options(options)
      options = options.symbolize_keys
      options.update(options[:params].symbolize_keys) if options[:params]

      if (overwrite = options.delete(:overwrite_params))
        options.update(@parameters.symbolize_keys)
        options.update(overwrite.symbolize_keys)
      end

      options
    end

  end
end
