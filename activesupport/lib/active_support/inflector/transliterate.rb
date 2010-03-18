# encoding: utf-8
require 'iconv'
require 'active_support/core_ext/string/multibyte'

module ActiveSupport
  module Inflector
    extend self
    
    # Replaces accented characters with their ascii equivalents.
    def transliterate(string)
      Iconv.iconv('ascii//ignore//translit', 'utf-8', string).to_s
    end

    if RUBY_VERSION >= '1.9'
      undef_method :transliterate
      def transliterate(string)
        proxy = ActiveSupport::Multibyte.proxy_class.new(string)
        proxy.normalize(:kd).gsub(/[^\x00-\x7F]+/, '')
      end

    # The iconv transliteration code doesn't function correctly
    # on some platforms, but it's very fast where it does function.
    elsif "foo" != (Inflector.transliterate("föö") rescue nil)
      undef_method :transliterate
      def transliterate(string)
        string.mb_chars.normalize(:kd). # Decompose accented characters
          gsub(/[^\x00-\x7F]+/, '')     # Remove anything non-ASCII entirely (e.g. diacritics).
      end
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