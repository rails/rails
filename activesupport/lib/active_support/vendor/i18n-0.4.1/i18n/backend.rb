module I18n
  module Backend
    autoload :ActiveRecord,          'i18n/backend/active_record'
    autoload :Base,                  'i18n/backend/base'
    autoload :InterpolationCompiler, 'i18n/backend/interpolation_compiler'
    autoload :Cache,                 'i18n/backend/cache'
    autoload :Cascade,               'i18n/backend/cascade'
    autoload :Chain,                 'i18n/backend/chain'
    autoload :Cldr,                  'i18n/backend/cldr'
    autoload :Fallbacks,             'i18n/backend/fallbacks'
    autoload :Flatten,               'i18n/backend/flatten'
    autoload :Gettext,               'i18n/backend/gettext'
    autoload :KeyValue,              'i18n/backend/key_value'
    autoload :Memoize,               'i18n/backend/memoize'
    autoload :Metadata,              'i18n/backend/metadata'
    autoload :Pluralization,         'i18n/backend/pluralization'
    autoload :Simple,                'i18n/backend/simple'
    autoload :Transliterator,        'i18n/backend/transliterator'
  end
end
