require 'rails/configuration'

module Rails
  class Railtie
    class Configuration
      def middleware
        @@default_middleware_stack ||= default_middleware
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

    private

      def method_missing(name, *args, &blk)
        if name.to_s =~ config_key_regexp
          return $2 == '=' ? options[$1] = args.first : options[$1]
        end
        super
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
          middleware.use(lambda { ActionController::SessionManagement.session_store_for(action_controller.session_store) }, lambda { action_controller.session })
          middleware.use('::ActionDispatch::Flash', :if => lambda { action_controller.session_store })
          middleware.use(lambda { metal_loader.build_middleware(metals) }, :if => lambda { metal_loader.metals.any? })
          middleware.use('ActionDispatch::ParamsParser')
          middleware.use('::Rack::MethodOverride')
          middleware.use('::ActionDispatch::Head')
        end
      end
    end
  end
end