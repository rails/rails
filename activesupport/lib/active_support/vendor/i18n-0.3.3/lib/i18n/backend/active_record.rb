require 'i18n/backend/base'
require 'i18n/backend/active_record/translation'

#
#  This backend reads translations from a Translations table in environment database. Note that the database
#  will not automatically be prepopulated with missing keys. You can achieve this effect with the ActiveRecordMissing backend, 
#  as the following example shows:
#
#     I18n.backend = I18n::Backend::Chain.new(I18n::Backend::ActiveRecord.new, I18.backend, I18n::Backend::ActiveRecordMissing.new)
#
module I18n
  module Backend
    class ActiveRecord
      autoload :Missing,     'i18n/backend/active_record/missing'
      autoload :StoreProcs,  'i18n/backend/active_record/store_procs'
      autoload :Translation, 'i18n/backend/active_record/translation'

      include Base

      def reload!
      end

      def store_translations(locale, data, options = {})
        separator = options[:separator] || I18n.default_separator
        wind_keys(data, separator).each do |key, v|
          Translation.locale(locale).lookup(expand_keys(key, separator), separator).delete_all
          Translation.create(:locale => locale.to_s, :key => key.to_s, :value => v)
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

        def lookup(locale, key, scope = [], separator = nil)
          return unless key

          separator ||= I18n.default_separator
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
