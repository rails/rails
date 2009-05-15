module ActionController
  # Dispatches requests to the appropriate controller and takes care of
  # reloading the app after each request when Dependencies.load? is true.
  class Dispatcher
    class << self
      def define_dispatcher_callbacks(cache_classes)
        unless cache_classes
          # Development mode callbacks
          before_dispatch :reload_application
          after_dispatch :cleanup_application

          ActionView::Helpers::AssetTagHelper.cache_asset_timestamps = false
        end

        if defined?(ActiveRecord)
          to_prepare(:activerecord_instantiate_observers) { ActiveRecord::Base.instantiate_observers }
        end

        after_dispatch :flush_logger if Base.logger && Base.logger.respond_to?(:flush)

        to_prepare do
          I18n.reload!
        end
      end

      # Add a preparation callback. Preparation callbacks are run before every
      # request in development mode, and before the first request in production
      # mode.
      #
      # An optional identifier may be supplied for the callback. If provided,
      # to_prepare may be called again with the same identifier to replace the
      # existing callback. Passing an identifier is a suggested practice if the
      # code adding a preparation block may be reloaded.
      def to_prepare(identifier = nil, &block)
        @prepare_dispatch_callbacks ||= ActiveSupport::Callbacks::CallbackChain.new
        callback = ActiveSupport::Callbacks::Callback.new(:prepare_dispatch, block, :identifier => identifier)
        @prepare_dispatch_callbacks.replace_or_append!(callback)
      end

      def run_prepare_callbacks
        new.send :run_callbacks, :prepare_dispatch
      end
    end

    cattr_accessor :router
    self.router = Routing::Routes

    cattr_accessor :middleware
    self.middleware = ActionDispatch::MiddlewareStack.new do |middleware|
      middlewares = File.join(File.dirname(__FILE__), "middlewares.rb")
      middleware.instance_eval(File.read(middlewares), middlewares, 1)
    end

    include ActiveSupport::Callbacks
    define_callbacks :prepare_dispatch, :before_dispatch, :after_dispatch

    def initialize
      @app = @@middleware.build(@@router)
      freeze
    end

    def call(env)
      run_callbacks :before_dispatch
      @app.call(env)
    ensure
      run_callbacks :after_dispatch, :enumerator => :reverse_each
    end

    def reload_application
      # Run prepare callbacks before every request in development mode
      run_callbacks :prepare_dispatch

      @@router.reload
    end

    def cleanup_application
      # Cleanup the application before processing the current request.
      ActiveRecord::Base.reset_subclasses if defined?(ActiveRecord)
      ActiveSupport::Dependencies.clear
      ActiveRecord::Base.clear_reloadable_connections! if defined?(ActiveRecord)
    end

    def flush_logger
      Base.logger.flush
    end
  end
end
