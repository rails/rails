# encoding: utf-8

module ActiveSupport #:nodoc:
  module Multibyte #:nodoc:
    if Kernel.const_defined?(:Encoding)
      # Returns a regular expression that matches valid characters in the current encoding
      def self.valid_character
        VALID_CHARACTER[Encoding.default_internal.to_s]
      end
    else
      def self.valid_character
        case $KCODE
        when 'UTF8'
          VALID_CHARACTER['UTF-8']
        when 'SJIS'
          VALID_CHARACTER['Shift_JIS']
        end
      end
    end

    if 'string'.respond_to?(:valid_encoding?)
      # Verifies the encoding of a string
      def self.verify(string)
        string.valid_encoding?
      end
    else
      def self.verify(string)
        if expression = valid_character
          for c in string.split(//)
            return false unless valid_character.match(c)
          end
        end
        true
      end
    end

    # Verifies the encoding of the string and raises an exception when it's not valid
    def self.verify!(string)
      raise EncodingError.new("Found characters with invalid encoding") unless verify(string)
    end

    if 'string'.respond_to?(:force_encoding)
      # Removes all invalid characters from the string.
      #
      # Note: this method is a no-op in Ruby 1.9
      def self.clean(string)
        string
      end
    else
      def self.clean(string)
        if expression = valid_character
          stripped = []; for c in string.split(//)
            stripped << c if valid_character.match(c)
          end; stripped.join
        else
          string
        end
      end
    end
  end
end