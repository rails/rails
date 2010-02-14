require 'active_support/ordered_options'
require 'rails/paths'
require 'rails/rack'

module Rails
  module Configuration
    # Holds coonfiguration shared between Railtie, Engine and Application.
    module Shared
      def middleware
        @@default_middleware_stack ||= ActionDispatch::MiddlewareStack.new.tap do |middleware|
          middleware.use('::ActionDispatch::Static', lambda { Rails.public_path }, :if => lambda { Rails.application.config.serve_static_assets })
          middleware.use('::Rack::Lock', :if => lambda { !Rails.application.config.allow_concurrency })
          middleware.use('::Rack::Runtime')
          middleware.use('::Rails::Rack::Logger')
          middleware.use('::ActionDispatch::ShowExceptions', lambda { Rails.application.config.consider_all_requests_local })
          middleware.use('::ActionDispatch::Callbacks', lambda { !Rails.application.config.cache_classes })
          middleware.use('::ActionDispatch::Cookies')
          middleware.use(lambda { ActionController::Base.session_store }, lambda { ActionController::Base.session_options })
          middleware.use('::ActionDispatch::Flash', :if => lambda { ActionController::Base.session_store })
          middleware.use(lambda { Rails.application.metal_loader.build_middleware(Rails.application.config.metals) }, :if => lambda { Rails.application.metal_loader.metals.any? })
          middleware.use('ActionDispatch::ParamsParser')
          middleware.use('::Rack::MethodOverride')
          middleware.use('::ActionDispatch::Head')
        end
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
    end

    # Generators configuration which uses method missing to wrap it in a nifty DSL.
    # It also allows you to set generators fallbacks and aliases.
    class Generators #:nodoc:
      attr_accessor :aliases, :options, :templates, :fallbacks, :colorize_logging

      def initialize
        @aliases = Hash.new { |h,k| h[k] = {} }
        @options = Hash.new { |h,k| h[k] = {} }
        @fallbacks = {}
        @templates = []
        @colorize_logging = true
      end

      def method_missing(method, *args)
        method = method.to_s.sub(/=$/, '').to_sym

        return @options[method] if args.empty?

        if method == :rails
          namespace, configuration = :rails, args.shift
        elsif args.first.is_a?(Hash)
          namespace, configuration = method, args.shift
        else
          namespace, configuration = args.shift, args.shift
          @options[:rails][method] = namespace
        end

        if configuration
          aliases = configuration.delete(:aliases)
          @aliases[namespace].merge!(aliases) if aliases
          @options[namespace].merge!(configuration)
        end
      end
    end

    # Holds configs deprecated in 3.0. Will be removed on 3.1.
    module Deprecated
      def frameworks(*args)
        raise "config.frameworks in no longer supported. See the generated " \
              "config/boot.rb for steps on how to limit the frameworks that " \
              "will be loaded"
      end
      alias :frameworks= :frameworks

      def view_path=(value)
        ActiveSupport::Deprecation.warn "config.view_path= is deprecated, " <<
          "please do paths.app.views= instead", caller
        paths.app.views = value
      end

      def view_path
        ActiveSupport::Deprecation.warn "config.view_path is deprecated, " <<
          "please do paths.app.views instead", caller
        paths.app.views.to_a.first
      end

      def routes_configuration_file=(value)
        ActiveSupport::Deprecation.warn "config.routes_configuration_file= is deprecated, " <<
          "please do paths.config.routes= instead", caller
        paths.config.routes = value
      end

      def routes_configuration_file
        ActiveSupport::Deprecation.warn "config.routes_configuration_file is deprecated, " <<
          "please do paths.config.routes instead", caller
        paths.config.routes.to_a.first
      end

      def database_configuration_file=(value)
        ActiveSupport::Deprecation.warn "config.database_configuration_file= is deprecated, " <<
          "please do paths.config.database= instead", caller
        paths.config.database = value
      end

      def database_configuration_file
        ActiveSupport::Deprecation.warn "config.database_configuration_file is deprecated, " <<
          "please do paths.config.database instead", caller
        paths.config.database.to_a.first
      end

      def log_path=(value)
        ActiveSupport::Deprecation.warn "config.log_path= is deprecated, " <<
          "please do paths.log= instead", caller
        paths.config.log = value
      end

      def log_path
        ActiveSupport::Deprecation.warn "config.log_path is deprecated, " <<
          "please do paths.log instead", caller
        paths.config.log.to_a.first
      end

      def controller_paths=(value)
        ActiveSupport::Deprecation.warn "config.controller_paths= is deprecated, " <<
          "please do paths.app.controllers= instead", caller
        paths.app.controllers = value
      end

      def controller_paths
        ActiveSupport::Deprecation.warn "config.controller_paths is deprecated, " <<
          "please do paths.app.controllers instead", caller
        paths.app.controllers.to_a.uniq
      end
    end
  end
end
