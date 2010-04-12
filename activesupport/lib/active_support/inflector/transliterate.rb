# encoding: utf-8
require 'active_support/core_ext/string/multibyte'

module ActiveSupport
  module Inflector
    extend self

    # UTF-8 byte => ASCII approximate UTF-8 byte(s)
    ASCII_APPROXIMATIONS = {
      198 => [65, 69],   # Æ => AE
      208 => 68,         # Ð => D
      216 => 79,         # Ø => O
      222 => [84, 104],  # Þ => Þ
      223 => [115, 115], # ß => ss
      230 => [97, 101],  # æ => ae
      240 => 100,        # ð => d
      248 => 111,        # ø => o
      254 => [116, 104], # þ => th
      272 => 68,         # Đ => D
      273 => 100,        # đ => đ
      294 => 72,         # Ħ => H
      295 => 104,        # ħ => h
      305 => 105,        # ı => i
      306 => [73, 74],   # Ĳ =>IJ
      307 => [105, 106], # ĳ => ij
      312 => 107,        # ĸ => k
      319 => 76,         # Ŀ => L
      320 => 108,        # ŀ => l
      321 => 76,         # Ł => L
      322 => 108,        # ł => l
      329 => 110,        # ŉ => n
      330 => [78, 71],   # Ŋ => NG
      331 => [110, 103], # ŋ => ng
      338 => [79, 69],   # Œ => OE
      339 => [111, 101], # œ => oe
      358 => 84,         # Ŧ => T
      359 => 116         # ŧ => t
    }

    # Replaces accented characters with an ASCII approximation, or deletes it if none exsits.
    def transliterate(string)
      ActiveSupport::Multibyte::Chars.new(string).tidy_bytes.normalize(:d).unpack("U*").map do |char|
        ASCII_APPROXIMATIONS[char] || (char if char < 128)
      end.compact.flatten.pack("U*")
    end

    # Replaces special characters in a string so that it may be used as part of a 'pretty' URL.
    #
    # ==== Examples
    #
    #   class Person
    #     def to_param
    #       "#{id}-#{name.parameterize}"
    #     end
    #   end
    #
    #   @person = Person.find(1)
    #   # => #<Person id: 1, name: "Donald E. Knuth">
    #
    #   <%= link_to(@person.name, person_path(@person)) %>
    #   # => <a href="/person/1-donald-e-knuth">Donald E. Knuth</a>
    def parameterize(string, sep = '-')
      # replace accented chars with their ascii equivalents
      parameterized_string = transliterate(string)
      # Turn unwanted chars into the separator
      parameterized_string.gsub!(/[^a-z0-9\-_]+/i, sep)
      unless sep.nil? || sep.empty?
        re_sep = Regexp.escape(sep)
        # No more than one of the separator in a row.
        parameterized_string.gsub!(/#{re_sep}{2,}/, sep)
        # Remove leading/trailing separator.
        parameterized_string.gsub!(/^#{re_sep}|#{re_sep}$/i, '')
      end
      parameterized_string.downcase
    end
  end
end
