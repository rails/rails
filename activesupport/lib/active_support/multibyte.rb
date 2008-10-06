# encoding: utf-8

require 'active_support/multibyte/chars'
require 'active_support/multibyte/exceptions'
require 'active_support/multibyte/unicode_database'

module ActiveSupport #:nodoc:
  module Multibyte
    # A list of all available normalization forms. See http://www.unicode.org/reports/tr15/tr15-29.html for more
    # information about normalization.
    NORMALIZATION_FORMS = [:c, :kc, :d, :kd]

    # The Unicode version that is supported by the implementation
    UNICODE_VERSION = '5.1.0'

    # The default normalization used for operations that require normalization. It can be set to any of the
    # normalizations in NORMALIZATION_FORMS.
    #
    # Example:
    #   ActiveSupport::Multibyte.default_normalization_form = :c
    mattr_accessor :default_normalization_form
    self.default_normalization_form = :kc

    # The proxy class returned when calling mb_chars. You can use this accessor to configure your own proxy
    # class so you can support other encodings. See the ActiveSupport::Multibyte::Chars implementation for
    # an example how to do this.
    #
    # Example:
    #   ActiveSupport::Multibyte.proxy_class = CharsForUTF32
    mattr_accessor :proxy_class
    self.proxy_class = ActiveSupport::Multibyte::Chars
  end
end
