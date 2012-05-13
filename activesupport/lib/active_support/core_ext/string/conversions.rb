# encoding: utf-8
require 'date'
require 'active_support/core_ext/time/publicize_conversion_methods'
require 'active_support/core_ext/time/calculations'

class String
  # Returns the codepoint of the first character of the string, assuming a
  # single-byte character encoding:
  #
  #   "a".ord # => 97
  #   "à".ord # => 224, in ISO-8859-1
  #
  # This method is defined in Ruby 1.8 for Ruby 1.9 forward compatibility on
  # these character encodings.
  #
  # <tt>ActiveSupport::Multibyte::Chars#ord</tt> is forward compatible with
  # Ruby 1.9 on UTF8 strings:
  #
  #   "a".mb_chars.ord # => 97
  #   "à".mb_chars.ord # => 224, in UTF8
  #
  # Note that the 224 is different in both examples. In ISO-8859-1 "à" is
  # represented as a single byte, 224. In UTF8 it is represented with two
  # bytes, namely 195 and 160, but its Unicode codepoint is 224. If we
  # call +ord+ on the UTF8 string "à" the return value will be 195. That is
  # not an error, because UTF8 is unsupported, the call itself would be
  # bogus.
  def ord
    self[0]
  end unless method_defined?(:ord)

  # +getbyte+ backport from Ruby 1.9
  alias_method :getbyte, :[] unless method_defined?(:getbyte)

  # Form can be either :utc (default) or :local.
  def to_time(form = :utc)
    return nil if self.blank?
    d = ::Date._parse(self, false).values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction, :offset).map { |arg| arg || 0 }
    d[6] *= 1000000
    ::Time.send("#{form}_time", *d[0..6]) - d[7]
  end

  # Converts a string to a Date value.
  #
  #   "1-1-2012".to_date   #=> Sun, 01 Jan 2012
  #   "01/01/2012".to_date #=> Sun, 01 Jan 2012
  #   "2012-12-13".to_date #=> Thu, 13 Dec 2012
  #   "12/13/2012".to_date #=> ArgumentError: invalid date
  def to_date
    return nil if self.blank?
    ::Date.new(*::Date._parse(self, false).values_at(:year, :mon, :mday))
  end

  # Converts a string to a DateTime value.
  #
  #   "1-1-2012".to_datetime            #=> Sun, 01 Jan 2012 00:00:00 +0000
  #   "01/01/2012 23:59:59".to_datetime #=> Sun, 01 Jan 2012 23:59:59 +0000
  #   "2012-12-13 12:50".to_datetime    #=> Thu, 13 Dec 2012 12:50:00 +0000
  #   "12/13/2012".to_datetime          #=> ArgumentError: invalid date
  def to_datetime
    return nil if self.blank?
    d = ::Date._parse(self, false).values_at(:year, :mon, :mday, :hour, :min, :sec, :zone, :sec_fraction).map { |arg| arg || 0 }
    d[5] += d.pop
    ::DateTime.civil(*d)
  end
end
