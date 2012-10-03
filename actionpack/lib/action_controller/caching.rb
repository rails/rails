require 'fileutils'
require 'uri'
require 'set'

module ActionController
  # \Caching is a cheap way of speeding up slow applications by keeping the result of
  # calculations, renderings, and database calls around for subsequent requests.
  #
  # You can read more about each approach and the sweeping assistance by clicking the
  # modules below.
  #
  # Note: To turn off all caching and sweeping, set
  #   config.action_controller.perform_caching = false.
  #
  # == \Caching stores
  #
  # All the caching stores from ActiveSupport::Cache are available to be used as backends
  # for Action Controller caching.
  #
  # Configuration examples (MemoryStore is the default):
  #
  #   config.action_controller.cache_store = :memory_store
  #   config.action_controller.cache_store = :file_store, '/path/to/cache/directory'
  #   config.action_controller.cache_store = :mem_cache_store, 'localhost'
  #   config.action_controller.cache_store = :mem_cache_store, Memcached::Rails.new('localhost:11211')
  #   config.action_controller.cache_store = MyOwnStore.new('parameter')
  module Caching
    extend ActiveSupport::Concern
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Fragments
      autoload :Sweeper, 'action_controller/caching/sweeping'
      autoload :Sweeping, 'action_controller/caching/sweeping'
    end

    module ConfigMethods
      def cache_store
        config.cache_store
      end

      def cache_store=(store)
        config.cache_store = ActiveSupport::Cache.lookup_store(store)
      end

      private
        def cache_configured?
          perform_caching && cache_store
        end
    end

    include RackDelegation
    include AbstractController::Callbacks

    include ConfigMethods
    include Fragments
    include Sweeping if defined?(ActiveRecord)

    included do
      extend ConfigMethods

      config_accessor :default_static_extension
      self.default_static_extension ||= '.html'

      def self.page_cache_extension=(extension)
        ActiveSupport::Deprecation.deprecation_warning(:page_cache_extension, :default_static_extension)
        self.default_static_extension = extension
      end

      def self.page_cache_extension
        ActiveSupport::Deprecation.deprecation_warning(:page_cache_extension, :default_static_extension)
        default_static_extension
      end

      config_accessor :perform_caching
      self.perform_caching = true if perform_caching.nil?
    end

    def caching_allowed?
      request.get? && response.status == 200
    end

    protected
      # Convenience accessor.
      def cache(key, options = {}, &block)
        if cache_configured?
          cache_store.fetch(ActiveSupport::Cache.expand_cache_key(key, :controller), options, &block)
        else
          yield
        end
      end
  end
end
