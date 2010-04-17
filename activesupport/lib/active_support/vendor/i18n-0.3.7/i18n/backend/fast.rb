# encoding: utf-8

# The Fast module contains optimizations that can tremendously speed up the
# lookup process on the Simple backend. It works by flattening the nested
# translation hash to a flat hash (e.g. { :a => { :b => 'c' } } becomes
# { :'a.b' => 'c' }).
#
# To enable these optimizations you can simply include the Fast module to
# the Simple backend:
#
#   I18n::Backend::Simple.send(:include, I18n::Backend::Fast)
module I18n
  module Backend
    module Fast
      include Links

      def reset_flattened_translations!
        @flattened_translations = nil
      end

      def flattened_translations
        @flattened_translations ||= flatten_translations(translations)
      end

      def merge_translations(locale, data, options = {})
        super
        reset_flattened_translations!
      end

      def init_translations
        super
        reset_flattened_translations!
      end

      protected
        def flatten_translations(translations)
          # don't flatten locale roots
          translations.inject({}) do |result, (locale, translations)|
            result[locale] = wind_keys(translations, nil, true)
            result[locale].each do |key, value|
              store_link(locale, key, value) if value.is_a?(Symbol)
            end
            result
          end
        end

        def lookup(locale, key, scope = nil, options = {})
          return unless key
          init_translations unless initialized?

          return nil unless flattened_translations.has_key?(locale.to_sym)

          separator = options[:separator]
          if separator && I18n.default_separator != separator
            key   = cleanup_non_standard_separator(key, separator)
            scope = Array(scope).map{|k| cleanup_non_standard_separator(k, separator)} if scope
          end
          
          key = resolve_link(locale, key)
          key = (Array(scope) + [key]).join(I18n.default_separator) if scope
          flattened_translations[locale.to_sym][key.to_sym]
        end

        def cleanup_non_standard_separator(key, user_separator)
          escape_default_separator(key).tr(user_separator, I18n.default_separator)
        end
    end
  end
end