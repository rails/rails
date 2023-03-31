# frozen_string_literal: true

module ActionController
  # = Action Controller \Caching
  #
  # \Caching is a cheap way of speeding up slow applications by keeping the result of
  # calculations, renderings, and database calls around for subsequent requests.
  #
  # You can read more about each approach by clicking the modules below.
  #
  # Note: To turn off all caching provided by Action Controller, set
  #   config.action_controller.perform_caching = false
  #
  # == \Caching stores
  #
  # All the caching stores from ActiveSupport::Cache are available to be used as backends
  # for Action Controller caching.
  #
  # Configuration examples (FileStore is the default):
  #
  #   config.action_controller.cache_store = :memory_store
  #   config.action_controller.cache_store = :file_store, '/path/to/cache/directory'
  #   config.action_controller.cache_store = :mem_cache_store, 'localhost'
  #   config.action_controller.cache_store = :mem_cache_store, Memcached::Rails.new('localhost:11211')
  #   config.action_controller.cache_store = MyOwnStore.new('parameter')
  module Caching
    extend ActiveSupport::Concern

    included do
      include AbstractController::Caching
    end

    private
      def instrument_payload(key)
        {
          controller: controller_name,
          action: action_name,
          key: key
        }
      end

      def instrument_name
        "action_controller"
      end
  end
end
