# Deprecates the use of the former message interpolation syntax in activerecord
# as in "must have %d characters". The new syntax uses explicit variable names
# as in "{{value}} must have {{count}} characters".

require 'i18n/backend/simple'
module I18n
  module Backend
    class Simple
      DEPRECATED_INTERPOLATORS = { '%d' => '{{count}}', '%s' => '{{value}}' }

      protected
        def interpolate_with_deprecated_syntax(locale, string, values = {})
          return string unless string.is_a?(String) && !values.empty?

          string = string.gsub(/%d|%s/) do |s|
            instead = DEPRECATED_INTERPOLATORS[s]
            ActiveSupport::Deprecation.warn "using #{s} in messages is deprecated; use #{instead} instead."
            instead
          end

          interpolate_without_deprecated_syntax(locale, string, values)
        end
        alias_method_chain :interpolate, :deprecated_syntax
    end
  end
end