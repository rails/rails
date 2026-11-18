# frozen_string_literal: true

module AbstractController
  module Caching
    extend ActiveSupport::Concern
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Fragments
    end

    module ConfigMethods
      def cache_store
        config[:cache_store]
      end

      def cache_store=(store)
        config[:cache_store] = ActiveSupport::Cache.lookup_store(*store)
      end

      private
        def cache_configured?
          perform_caching && cache_store
        end
    end

    include ConfigMethods
    include AbstractController::Caching::Fragments

    module ClassMethods
      def view_cache_dependency(&dependency)
        self._view_cache_dependencies = [
          *_view_cache_dependencies, ActiveSupport::Ractors.try_shareable_proc(dependency)
        ].freeze
      end
    end

    Config.generate_accessors(self, :default_static_extension, :perform_caching, :enable_fragment_cache_logging)

    included do
      extend ConfigMethods

      self.default_static_extension ||= ".html"
      self.perform_caching = true if perform_caching.nil?
      self.enable_fragment_cache_logging = false

      class_attribute :_view_cache_dependencies, default: [].freeze
      helper_method :view_cache_dependencies if respond_to?(:helper_method)
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
