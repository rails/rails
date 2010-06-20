# encoding: utf-8
#
# Memoize module simply memoizes the values returned by lookup using
# a flat hash and can tremendously speed up the lookup process in a backend.
#
# To enable it you can simply include the Memoize module to your backend:
#
#   I18n::Backend::Simple.send(:include, I18n::Backend::Memoize)
#
# Notice that it's the responsibility of the backend to define whenever the
# cache should be cleaned.
module I18n
  module Backend
    module Memoize
      def available_locales
        @memoized_locales ||= super
      end

      def store_translations(locale, data, options = {})
        reset_memoizations!(locale)
        super
      end

      def reload!
        reset_memoizations!
        super
      end

      protected

        def lookup(locale, key, scope = nil, options = {})
          flat_key  = I18n::Backend::Flatten.normalize_flat_keys(locale,
            key, scope, options[:separator]).to_sym
          flat_hash = memoized_lookup[locale.to_sym]
          flat_hash.key?(flat_key) ? flat_hash[flat_key] : (flat_hash[flat_key] = super)
        end

        def memoized_lookup
          @memoized_lookup ||= Hash.new { |h, k| h[k] = {} }
        end

        def reset_memoizations!(locale=nil)
          @memoized_locales = nil
          (locale ? memoized_lookup[locale.to_sym] : memoized_lookup).clear
        end
    end
  end
end