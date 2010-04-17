require 'i18n/backend/base'
require 'i18n/backend/active_record/translation'

module I18n
  module Backend
    class ActiveRecord
      autoload :Missing,     'i18n/backend/active_record/missing'
      autoload :StoreProcs,  'i18n/backend/active_record/store_procs'
      autoload :Translation, 'i18n/backend/active_record/translation'

      include Base, Links

      def reload!
      end

      def store_translations(locale, data, options = {})
        separator = options[:separator] || I18n.default_separator
        wind_keys(data, separator).each do |key, value|
          store_link(locale, key, value) if value.is_a?(Symbol)
          Translation.locale(locale).lookup(expand_keys(key, separator), separator).delete_all
          Translation.create(:locale => locale.to_s, :key => key.to_s, :value => value)
        end
      end

      def available_locales
        begin
          Translation.available_locales
        rescue ::ActiveRecord::StatementInvalid
          []
        end
      end

      protected

        def lookup(locale, key, scope = [], options = {})
          return unless key

          separator = options[:separator] || I18n.default_separator

          key = resolve_link(locale, key)
          key = (Array(scope) + Array(key)).join(separator)
          result = Translation.locale(locale).lookup(key, separator).all

          if result.empty?
            return nil
          elsif result.first.key == key
            return result.first.value
          else
            chop_range = (key.size + separator.size)..-1
            result = result.inject({}) do |hash, r|
              hash[r.key.slice(chop_range)] = r.value
              hash
            end
            deep_symbolize_keys(unwind_keys(result, separator))
          end
        end

        # For a key :'foo.bar.baz' return ['foo', 'foo.bar', 'foo.bar.baz']
        def expand_keys(key, separator = I18n.default_separator)
          key.to_s.split(separator).inject([]) do |keys, key|
            keys << [keys.last, key].compact.join(separator)
          end
        end
    end
  end
end
