module I18n
  module Backend
    autoload :ActiveRecord,          'i18n/backend/active_record'
    autoload :Base,                  'i18n/backend/base'
    autoload :Cache,                 'i18n/backend/cache'
    autoload :Cascade,               'i18n/backend/cascade'
    autoload :Chain,                 'i18n/backend/chain'
    autoload :Cldr,                  'i18n/backend/cldr'
    autoload :Fallbacks,             'i18n/backend/fallbacks'
    autoload :Fast,                  'i18n/backend/fast'
    autoload :Gettext,               'i18n/backend/gettext'
    autoload :Helpers,               'i18n/backend/helpers'
    autoload :Links,                 'i18n/backend/links'
    autoload :InterpolationCompiler, 'i18n/backend/interpolation_compiler'
    autoload :Metadata,              'i18n/backend/metadata'
    autoload :Pluralization,         'i18n/backend/pluralization'
    autoload :Simple,                'i18n/backend/simple'
  end
end
