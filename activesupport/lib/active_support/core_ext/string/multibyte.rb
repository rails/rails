# frozen_string_literal: true

class String
  # Returns +true+ if string has utf_8 encoding.
  #
  #   utf_8_str = "some string".encode "UTF-8"
  #   iso_str = "some string".encode "ISO-8859-1"
  #
  #   utf_8_str.is_utf8? # => true
  #   iso_str.is_utf8?   # => false
  def is_utf8?
    case encoding
    when Encoding::UTF_8, Encoding::US_ASCII
      valid_encoding?
    when Encoding::ASCII_8BIT
      dup.force_encoding(Encoding::UTF_8).valid_encoding?
    else
      false
    end
  end
end
