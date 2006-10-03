module ActiveSupport::Multibyte
  DEFAULT_NORMALIZATION_FORM = :kc
  NORMALIZATIONS_FORMS = [:c, :kc, :d, :kd]
  UNICODE_VERSION = '5.0.0'
end

require 'active_support/multibyte/chars'