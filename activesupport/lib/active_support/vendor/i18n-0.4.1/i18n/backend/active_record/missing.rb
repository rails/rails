#  This extension stores translation stub records for missing translations to
#  the database.
#
#  This is useful if you have a web based translation tool. It will populate
#  the database with untranslated keys as the application is being used. A
#  translator can then go through these and add missing translations.
#
#  Example usage:
#
#     I18n::Backend::Chain.send(:include, I18n::Backend::ActiveRecord::Missing)
#     I18n.backend = I18nChainBackend.new(I18n::Backend::ActiveRecord.new, I18n::Backend::Simple.new)
#
#  Stub records for pluralizations will also be created for each key defined
#  in i18n.plural.keys.
#
#  For example:
#
#    # en.yml
#    en:
#      i18n:
#        plural:
#          keys: [:zero, :one, :other]
#
#    # pl.yml
#    pl:
#      i18n:
#        plural:
#          keys: [:zero, :one, :few, :other]
#
#  It will also persist interpolation keys in Translation#interpolations so
#  translators will be able to review and use them.
module I18n
  module Backend
    class ActiveRecord
      module Missing
        def store_default_translations(locale, key, options = {})
          count, scope, default, separator = options.values_at(:count, *Base::RESERVED_KEYS)
          separator ||= I18n.default_separator

          keys = I18n.normalize_keys(locale, key, scope, separator)[1..-1]
          key = keys.join(separator || I18n.default_separator)

          unless ActiveRecord::Translation.locale(locale).lookup(key).exists?
            interpolations = options.reject { |name, value| Base::RESERVED_KEYS.include?(name) }.keys
            keys = count ? I18n.t('i18n.plural.keys', :locale => locale).map { |k| [key, k].join(separator) } : [key]
            keys.each { |key| store_default_translation(locale, key, interpolations) }
          end
        end

        def store_default_translation(locale, key, interpolations)
          translation = ActiveRecord::Translation.new :locale => locale.to_s, :key => key
          translation.interpolations = interpolations
          translation.save
        end

        def translate(locale, key, options = {})
          super
        rescue I18n::MissingTranslationData => e
          self.store_default_translations(locale, key, options)
          raise e
        end
      end
    end
  end
end
