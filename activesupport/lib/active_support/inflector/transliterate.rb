# encoding: utf-8
require 'active_support/core_ext/string/multibyte'
require 'active_support/i18n'

module ActiveSupport
  module Inflector

    # Replaces non-ASCII characters with an ASCII approximation, or if none
    # exists, a replacement character which defaults to "?".
    #
    #    transliterate('Ærøskøbing')
    #    # => "AEroskobing"
    #
    # Default approximations are provided for Western/Latin characters,
    # e.g, "ø", "ñ", "é", "ß", etc.
    #
    # This method is I18n aware, so you can set up custom approximations for a
    # locale. This can be useful, for example, to transliterate German's "ü"
    # and "ö" to "ue" and "oe", or to add support for transliterating Russian
    # to ASCII.
    #
    # In order to make your custom transliterations available, you must set
    # them as the <tt>i18n.transliterate.rule</tt> i18n key:
    #
    #   # Store the transliterations in locales/de.yml
    #   i18n:
    #     transliterate:
    #       rule:
    #         ü: "ue"
    #         ö: "oe"
    #
    #   # Or set them using Ruby
    #   I18n.backend.store_translations(:de, i18n: {
    #     transliterate: {
    #       rule: {
    #         'ü' => 'ue',
    #         'ö' => 'oe'
    #       }
    #     }
    #   })
    #
    # The value for <tt>i18n.transliterate.rule</tt> can be a simple Hash that
    # maps characters to ASCII approximations as shown above, or, for more
    # complex requirements, a Proc:
    #
    #   I18n.backend.store_translations(:de, i18n: {
    #     transliterate: {
    #       rule: ->(string) { MyTransliterator.transliterate(string) }
    #     }
    #   })
    #
    # Now you can have different transliterations for each locale:
    #
    #   I18n.locale = :en
    #   transliterate('Jürgen')
    #   # => "Jurgen"
    #
    #   I18n.locale = :de
    #   transliterate('Jürgen')
    #   # => "Juergen"
    def transliterate(string, replacement = "?")
      I18n.transliterate(ActiveSupport::Multibyte::Unicode.normalize(
        ActiveSupport::Multibyte::Unicode.tidy_bytes(string), :c),
          :replacement => replacement)
    end

    # Replaces special characters in a string so that it may be used as part of
    # a 'pretty' URL.
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
