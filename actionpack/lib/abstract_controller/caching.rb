# frozen_string_literal: true

# :markup: markdown

module AbstractController
  module Caching
    extend ActiveSupport::Concern
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Fragments
    end

    module ConfigMethods
      def cache_store
        config.cache_store
      end

      def cache_store=(store)
        config.cache_store = ActiveSupport::Cache.lookup_store(*store)
      end

      private
        def cache_configured?
          perform_caching && cache_store
        end
    end

    include ConfigMethods
    include AbstractController::Caching::Fragments

    included do
      extend ConfigMethods

      singleton_class.delegate :default_static_extension, :default_static_extension=, to: :config
      delegate :default_static_extension, :default_static_extension=, to: :config
      self.default_static_extension ||= ".html"

      singleton_class.delegate :perform_caching, :perform_caching=, to: :config
      delegate :perform_caching, :perform_caching=, to: :config
      self.perform_caching = true if perform_caching.nil?

      singleton_class.delegate :enable_fragment_cache_logging, :enable_fragment_cache_logging=, to: :config
      delegate :enable_fragment_cache_logging, :enable_fragment_cache_logging=, to: :config
      self.enable_fragment_cache_logging = false

      class_attribute :_view_cache_dependencies, default: []
      helper_method :view_cache_dependencies if respond_to?(:helper_method)
    end

    module ClassMethods
      def view_cache_dependency(&dependency)
        self._view_cache_dependencies += [dependency]
      end
    end

    def view_cache_dependencies
      self.class._view_cache_dependencies.filter_map { |dep| instance_exec(&dep) }
    end

    private
      # Convenience accessor.
      def cache(key, options = {}, &block) # :doc:
        if cache_configured?
          cache_store.fetch(ActiveSupport::Cache.expand_cache_key(key, :controller), options, &block)
        else
          yield
        end
      end
  end
end
