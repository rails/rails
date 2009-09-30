require 'active_support/core_ext/module/delegation'

module ActionController
  # Dispatches requests to the appropriate controller and takes care of
  # reloading the app after each request when Dependencies.load? is true.
  class Dispatcher
    cattr_accessor :prepare_each_request
    self.prepare_each_request = false

    class << self
      def define_dispatcher_callbacks(cache_classes)
        unless cache_classes
          # Run prepare callbacks before every request in development mode
          self.prepare_each_request = true

          # Development mode callbacks
          ActionDispatch::Callbacks.before_dispatch do |app|
            ActionController::Routing::Routes.reload
          end

          ActionDispatch::Callbacks.after_dispatch do
            # Cleanup the application before processing the current request.
            ActiveRecord::Base.reset_subclasses if defined?(ActiveRecord)
            ActiveSupport::Dependencies.clear
            ActiveRecord::Base.clear_reloadable_connections! if defined?(ActiveRecord)
          end

          ActionView::Helpers::AssetTagHelper.cache_asset_timestamps = false
        end

        if defined?(ActiveRecord)
          to_prepare(:activerecord_instantiate_observers) do
            ActiveRecord::Base.instantiate_observers
          end
        end

        if Base.logger && Base.logger.respond_to?(:flush)
          after_dispatch do
            Base.logger.flush
          end
        end

        to_prepare do
          I18n.reload!
        end
      end

      delegate :to_prepare, :before_dispatch, :around_dispatch, :after_dispatch,
        :to => ActionDispatch::Callbacks

      def new
        # DEPRECATE Rails application fallback
        Rails.application
      end
    end
  end
end
