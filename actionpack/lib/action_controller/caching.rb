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

      # Most Rails requests do not have an extension, such as <tt>/weblog/new</tt>.
      # In these cases, the page caching mechanism will add one in order to make it
      # easy for the cached files to be picked up properly by the web server. By
      # default, this cache extension is <tt>.html</tt>. If you want something else,
      # like <tt>.php</tt> or <tt>.shtml</tt>, just set Base.page_cache_extension.
      # In cases where a request already has an extension, such as <tt>.xml</tt>
      # or <tt>.rss</tt>, page caching will not add an extension. This allows it
      # to work well with RESTful apps.
      config_accessor :page_cache_extension
      self.page_cache_extension ||= '.html'

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
