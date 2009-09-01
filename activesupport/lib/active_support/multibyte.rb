module ActiveSupport
  module Multibyte #:nodoc:
    DEFAULT_NORMALIZATION_FORM = :kc
    NORMALIZATIONS_FORMS = [:c, :kc, :d, :kd]
    UNICODE_VERSION = '5.0.0'

    # Regular expressions that describe valid byte sequences for a character
    VALID_CHARACTER = {
      # Borrowed from the Kconv library by Shinji KONO - (also as seen on the W3C site)
      'UTF-8' => /\A(?:
                 [\x00-\x7f]                                         |
                 [\xc2-\xdf] [\x80-\xbf]                             |
                 \xe0        [\xa0-\xbf] [\x80-\xbf]                 |
                 [\xe1-\xef] [\x80-\xbf] [\x80-\xbf]                 |
                 \xf0        [\x90-\xbf] [\x80-\xbf] [\x80-\xbf]     |
                 [\xf1-\xf3] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf]     |
                 \xf4        [\x80-\x8f] [\x80-\xbf] [\x80-\xbf])\z /xn,
      # Quick check for valid Shift-JIS characters, disregards the odd-even pairing
      'Shift_JIS' => /\A(?:
                 [\x00-\x7e \xa1-\xdf]                                     |
                 [\x81-\x9f \xe0-\xef] [\x40-\x7e \x80-\x9e \x9f-\xfc])\z /xn
    }
  end
end

require 'active_support/multibyte/chars'
require 'active_support/multibyte/utils'