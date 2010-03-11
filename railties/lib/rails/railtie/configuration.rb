require 'rails/configuration'

module Rails
  class Railtie
    class Configuration
      attr_accessor :cookie_secret

      def initialize
        @session_store = :cookie_store
        @session_options = {}
      end

      # Holds generators configuration:
      #
      #   config.generators do |g|
      #     g.orm             :datamapper, :migration => true
      #     g.template_engine :haml
      #     g.test_framework  :rspec
      #   end
      #
      # If you want to disable color in console, do:
      #
      #   config.generators.colorize_logging = false
      #
      def generators
        @@generators ||= Rails::Configuration::Generators.new
        if block_given?
          yield @@generators
        else
          @@generators
        end
      end

      def after_initialize_blocks
        @@after_initialize_blocks ||= []
      end

      def after_initialize(&blk)
        after_initialize_blocks << blk if blk
      end

      def to_prepare_blocks
        @@to_prepare_blocks ||= []
      end

      def to_prepare(&blk)
        to_prepare_blocks << blk if blk
      end

      def respond_to?(name)
        super || name.to_s =~ config_key_regexp
      end

      def metal_loader
        @metal_loader ||= Rails::Application::MetalLoader.new
      end

      def session_store(*args)
        if args.empty?
          case @session_store
          when :disabled
            nil
          when :active_record_store
            ActiveRecord::SessionStore
          when Symbol
            ActionDispatch::Session.const_get(@session_store.to_s.camelize)
          else
            @session_store
          end
        else
          @session_store = args.shift
          @session_options = args.shift || {}
        end
      end

    private

      def method_missing(name, *args, &blk)
        if name.to_s =~ config_key_regexp
          return $2 == '=' ? options[$1] = args.first : options[$1]
        end
        super
      end

      def session_options
        return @session_options unless @session_store == :cookie_store
        @session_options.merge(:secret => @cookie_secret)
      end

      def config_key_regexp
        bits = config_keys.map { |n| Regexp.escape(n.to_s) }.join('|')
        /^(#{bits})(?:=)?$/
      end

      def config_keys
        (Railtie.railtie_names + Engine.engine_names).map { |n| n.to_s }.uniq
      end

      def options
        @@options ||= Hash.new { |h,k| h[k] = ActiveSupport::OrderedOptions.new }
      end

      def default_middleware
        require 'action_dispatch'
        ActionDispatch::MiddlewareStack.new.tap do |middleware|
          middleware.use('::ActionDispatch::Static', lambda { Rails.public_path }, :if => lambda { serve_static_assets })
          middleware.use('::Rack::Lock', :if => lambda { !allow_concurrency })
          middleware.use('::Rack::Runtime')
          middleware.use('::Rails::Rack::Logger')
          middleware.use('::ActionDispatch::ShowExceptions', lambda { consider_all_requests_local })
          middleware.use("::ActionDispatch::RemoteIp", lambda { action_dispatch.ip_spoofing_check }, lambda { action_dispatch.trusted_proxies })
          middleware.use('::Rack::Sendfile', lambda { action_dispatch.x_sendfile_header })
          middleware.use('::ActionDispatch::Callbacks', lambda { !cache_classes })
          middleware.use('::ActionDispatch::Cookies')
          middleware.use(lambda { session_store }, lambda { session_options })
          middleware.use('::ActionDispatch::Flash', :if => lambda { session_store })
          middleware.use(lambda { metal_loader.build_middleware(metals) }, :if => lambda { metal_loader.metals.any? })
          middleware.use('ActionDispatch::ParamsParser')
          middleware.use('::Rack::MethodOverride')
          middleware.use('::ActionDispatch::Head')
        end
      end
    end
  end
end