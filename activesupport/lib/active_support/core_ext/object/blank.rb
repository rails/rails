# :markup: markdown
# frozen_string_literal: true

require "concurrent/map"

class Object
  # An object is blank if it's false, empty, or a whitespace string.
  # For example, `nil`, '', '   ', [], {}, and `false` are all blank.
  #
  # This simplifies
  #
  # ```ruby
  # !address || address.empty?
  # ```
  #
  # to
  #
  # ```ruby
  # address.blank?
  # ```
  #
  # @return [true, false]
  def blank?
    respond_to?(:empty?) ? !!empty? : false
  end

  # An object is present if it's not blank.
  #
  # @return [true, false]
  def present?
    !blank?
  end

  # Returns the receiver if it's present otherwise returns `nil`.
  # `object.presence` is equivalent to
  #
  # ```ruby
  # object.present? ? object : nil
  # ```
  #
  # For example, something like
  #
  # ```ruby
  # state   = params[:state]   if params[:state].present?
  # country = params[:country] if params[:country].present?
  # region  = state || country || 'US'
  # ```
  #
  # becomes
  #
  # ```ruby
  # region = params[:state].presence || params[:country].presence || 'US'
  # ```
  #
  # @return [Object]
  def presence
    self if present?
  end
end

class NilClass
  # `nil` is blank:
  #
  # ```ruby
  # nil.blank? # => true
  # ```
  #
  # @return [true]
  def blank?
    true
  end

  def present? # :nodoc:
    false
  end
end

class FalseClass
  # `false` is blank:
  #
  # ```ruby
  # false.blank? # => true
  # ```
  #
  # @return [true]
  def blank?
    true
  end

  def present? # :nodoc:
    false
  end
end

class TrueClass
  # `true` is not blank:
  #
  # ```ruby
  # true.blank? # => false
  # ```
  #
  # @return [false]
  def blank?
    false
  end

  def present? # :nodoc:
    true
  end
end

class Array
  # An array is blank if it's empty:
  #
  # ```ruby
  # [].blank?      # => true
  # [1,2,3].blank? # => false
  # ```
  #
  # @return [true, false]
  alias_method :blank?, :empty?

  def present? # :nodoc:
    !empty?
  end
end

class Hash
  # A hash is blank if it's empty:
  #
  # ```ruby
  # {}.blank?                # => true
  # { key: 'value' }.blank?  # => false
  # ```
  #
  # @return [true, false]
  alias_method :blank?, :empty?

  def present? # :nodoc:
    !empty?
  end
end

class Symbol
  # A Symbol is blank if it's empty:
  #
  # ```ruby
  # :''.blank?     # => true
  # :symbol.blank? # => false
  # ```
  alias_method :blank?, :empty?

  def present? # :nodoc:
    !empty?
  end
end

module ActiveSupport
  module Blank # :nodoc:
    # Byte scanner behind String#blank? for ASCII-only and valid UTF-8 strings.
    # Kept out of String#blank? so that method has no local variables, which
    # YJIT initializes on every call; that shows on empty strings.
    def self.whitespace_only?(string)
      i = 0
      size = string.bytesize
      while i < size
        byte = string.getbyte(i)
        if byte == 32 || (byte >= 9 && byte <= 13)
          i += 1
        elsif byte == 0xc2 # U+0085, U+00A0
          codepoint = 0x80 | (string.getbyte(i + 1) & 0x3f)
          return false unless codepoint == 0x85 || codepoint == 0xa0
          i += 2
        elsif byte >= 0xe1 && byte <= 0xe3 # U+1680, U+2000..U+200A, U+2028, U+2029, U+202F, U+205F, U+3000
          codepoint = ((byte & 0x0f) << 12) | ((string.getbyte(i + 1) & 0x3f) << 6) | (string.getbyte(i + 2) & 0x3f)
          return false unless codepoint == 0x1680 || (codepoint >= 0x2000 && codepoint <= 0x200a) || codepoint == 0x2028 ||
            codepoint == 0x2029 || codepoint == 0x202f || codepoint == 0x205f || codepoint == 0x3000
          i += 3
        else
          return false
        end
      end
      true
    end
  end
end

class String
  BLANK_RE = /\A[[:space:]]*\z/
  ENCODED_BLANKS = Concurrent::Map.new do |h, enc|
    h[enc] = Regexp.new(BLANK_RE.source.encode(enc), BLANK_RE.options | Regexp::FIXEDENCODING)
  end

  # A string is blank if it's empty or contains whitespaces only:
  #
  # ```ruby
  # ''.blank?       # => true
  # '   '.blank?    # => true
  # "\t\n\r".blank? # => true
  # ' blah '.blank? # => false
  # ```
  #
  # Unicode whitespace is supported:
  #
  # ```ruby
  # "\u00a0".blank? # => true
  # ```
  #
  # @return [true, false]
  def blank?
    return true if empty?

    # Scanning bytes beats the regexp engine under YJIT and allocates nothing.
    # It is exact for ASCII-only strings and for valid UTF-8; other encodings
    # keep using the regexp, which knows each encoding's whitespace table.
    if ascii_only?
      # A printable first character settles it without another call.
      getbyte(0) <= 32 && ActiveSupport::Blank.whitespace_only?(self)
    elsif encoding == Encoding::UTF_8 && valid_encoding?
      ActiveSupport::Blank.whitespace_only?(self)
    else
      begin
        BLANK_RE.match?(self)
      rescue Encoding::CompatibilityError
        ENCODED_BLANKS[encoding].match?(self)
      end
    end
  end

  # Mirrors #blank? instead of calling it: the extra method call costs about
  # as much as the check itself.
  def present? # :nodoc:
    return false if empty?

    if ascii_only?
      getbyte(0) > 32 || !ActiveSupport::Blank.whitespace_only?(self)
    elsif encoding == Encoding::UTF_8 && valid_encoding?
      !ActiveSupport::Blank.whitespace_only?(self)
    else
      begin
        !BLANK_RE.match?(self)
      rescue Encoding::CompatibilityError
        !ENCODED_BLANKS[encoding].match?(self)
      end
    end
  end
end

class Numeric # :nodoc:
  # No number is blank:
  #
  # ```ruby
  # 1.blank? # => false
  # 0.blank? # => false
  # ```
  #
  # @return [false]
  def blank?
    false
  end

  def present?
    true
  end
end

class Time # :nodoc:
  # No Time is blank:
  #
  # ```ruby
  # Time.now.blank? # => false
  # ```
  #
  # @return [false]
  def blank?
    false
  end

  def present?
    true
  end
end
