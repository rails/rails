# frozen_string_literal: true

require "active_support/cache"

module ActiveSupport
  module Cache
    # This class is responsible for coercing input into a valid
    # key format and cache version for cache stores.
    #
    # The goal of this class is to provide a composable way
    # to build keys. You can put an instance of Key
    # into another instance of Key and it should produce
    # the same `cache_key` and `cache_version`.
    #
    # Example:
    #
    #   k1 = Key.new("foo")
    #   k2 = Key.new(k1)
    #   k1.cache_key == k2.cache_key
    #   # => true
    #
    class Key # :nodoc:
      @cache_object = nil

      def self.cache_object
        return @cache_object if @cache_object
        if defined?(Rails) && Rails.respond_to?(:cache)
          @cache_object = Rails.cache
        else
          @cache_object = ActiveSupport::Cache::Store.new
        end
      end

      def initialize(key)
        @key_parts = [key]
        @cache_key = nil
        @cache_version = nil
      end

      def cache_key
        @cache_key ||= self.class.cache_object.send(:expanded_key, @key_parts)
      end

      def cache_version
        @cache_version ||= self.class.cache_object.send(:expanded_version, @key_parts)

        if @cache_version == "/"
          nil
        else
          @cache_version
        end
      end

      def cache_key_with_version
        @cache_method_obj.send(:retrieve_cache_key, @key_parts)
      end

      def update(key)
        @key_parts << key
        @cache_key = nil
        @cache_version = nil
        self
      end
      alias :<< :update

      def length
        cache_key.length
      end

      private
        def cache_method_obj
          if @@has_rails_cache == :unknown
            @@has_rails_cache = defined?(Rails) && Rails.respond_to?(:cache)
          end

          if @@has_rails_cache
            Rails.cache
          else
            CACHE_METHOD_OBJ
          end
        end
    end
  end
end
