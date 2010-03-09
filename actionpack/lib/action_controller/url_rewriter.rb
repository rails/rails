require 'active_support/core_ext/hash/except'

module ActionController
  # Rewrites URLs for Base.redirect_to and Base.url_for in the controller.
  module UrlRewriter #:nodoc:
    RESERVED_OPTIONS = [:anchor, :params, :only_path, :host, :protocol, :port, :trailing_slash, :skip_relative_url_root]

    # ROUTES TODO: Class method code smell
    def self.rewrite(router, options)
      handle_positional_args(options)

      rewritten_url = ""

      path_segments = options.delete(:_path_segments)

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
      path = router.generate(path_options, path_segments || {})

      # ROUTES TODO: This can be called directly, so script_name should probably be set in the router
      rewritten_url << (options[:trailing_slash] ? path.sub(/\?|\z/) { "/" + $& } : path)
      rewritten_url << "##{Rack::Utils.escape(options[:anchor].to_param.to_s)}" if options[:anchor]

      rewritten_url
    end

  protected

    def self.handle_positional_args(options)
      return unless args = options.delete(:_positional_args)

      keys = options.delete(:_positional_keys)
      keys -= options.keys if args.size < keys.size - 1 # take format into account

      args = args.zip(keys).inject({}) do |h, (v, k)|
        h[k] = v
        h
      end

      # Tell url_for to skip default_url_options
      options.merge!(args)
    end

    def self.rewrite_authentication(options)
      if options[:user] && options[:password]
        "#{Rack::Utils.escape(options.delete(:user))}:#{Rack::Utils.escape(options.delete(:password))}@"
      else
        ""
      end
    end

  end
end
