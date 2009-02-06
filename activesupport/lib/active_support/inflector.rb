# encoding: utf-8
require 'singleton'
require 'iconv'

module ActiveSupport
  # The Inflector transforms words from singular to plural, class names to table names, modularized class names to ones without,
  # and class names to foreign keys. The default inflections for pluralization, singularization, and uncountable words are kept
  # in inflections.rb.
  #
  # The Rails core team has stated patches for the inflections library will not be accepted
  # in order to avoid breaking legacy applications which may be relying on errant inflections.
  # If you discover an incorrect inflection and require it for your application, you'll need
  # to correct it yourself (explained below).
  module Inflector
    extend self

    # A singleton instance of this class is yielded by Inflector.inflections, which can then be used to specify additional
    # inflection rules. Examples:
    #
    #   ActiveSupport::Inflector.inflections do |inflect|
    #     inflect.plural /^(ox)$/i, '\1\2en'
    #     inflect.singular /^(ox)en/i, '\1'
    #
    #     inflect.irregular 'octopus', 'octopi'
    #
    #     inflect.uncountable "equipment"
    #   end
    #
    # New rules are added at the top. So in the example above, the irregular rule for octopus will now be the first of the
    # pluralization and singularization rules that is runs. This guarantees that your rules run before any of the rules that may
    # already have been loaded.
    class Inflections
      include Singleton

      attr_reader :plurals, :singulars, :uncountables, :humans

      def initialize
        @plurals, @singulars, @uncountables, @humans = [], [], [], []
      end

      # Specifies a new pluralization rule and its replacement. The rule can either be a string or a regular expression.
      # The replacement should always be a string that may include references to the matched data from the rule.
      def plural(rule, replacement)
        @uncountables.delete(rule) if rule.is_a?(String)
        @uncountables.delete(replacement)
        @plurals.insert(0, [rule, replacement])
      end

      # Specifies a new singularization rule and its replacement. The rule can either be a string or a regular expression.
      # The replacement should always be a string that may include references to the matched data from the rule.
      def singular(rule, replacement)
        @uncountables.delete(rule) if rule.is_a?(String)
        @uncountables.delete(replacement)
        @singulars.insert(0, [rule, replacement])
      end

      # Specifies a new irregular that applies to both pluralization and singularization at the same time. This can only be used
      # for strings, not regular expressions. You simply pass the irregular in singular and plural form.
      #
      # Examples:
      #   irregular 'octopus', 'octopi'
      #   irregular 'person', 'people'
      def irregular(singular, plural)
        @uncountables.delete(singular)
        @uncountables.delete(plural)
        if singular[0,1].upcase == plural[0,1].upcase
          plural(Regexp.new("(#{singular[0,1]})#{singular[1..-1]}$", "i"), '\1' + plural[1..-1])
          singular(Regexp.new("(#{plural[0,1]})#{plural[1..-1]}$", "i"), '\1' + singular[1..-1])
        else
          plural(Regexp.new("#{singular[0,1].upcase}(?i)#{singular[1..-1]}$"), plural[0,1].upcase + plural[1..-1])
          plural(Regexp.new("#{singular[0,1].downcase}(?i)#{singular[1..-1]}$"), plural[0,1].downcase + plural[1..-1])
          singular(Regexp.new("#{plural[0,1].upcase}(?i)#{plural[1..-1]}$"), singular[0,1].upcase + singular[1..-1])
          singular(Regexp.new("#{plural[0,1].downcase}(?i)#{plural[1..-1]}$"), singular[0,1].downcase + singular[1..-1])
        end
      end

      # Add uncountable words that shouldn't be attempted inflected.
      #
      # Examples:
      #   uncountable "money"
      #   uncountable "money", "information"
      #   uncountable %w( money information rice )
      def uncountable(*words)
        (@uncountables << words).flatten!
      end

      # Specifies a humanized form of a string by a regular expression rule or by a string mapping.
      # When using a regular expression based replacement, the normal humanize formatting is called after the replacement.
      # When a string is used, the human form should be specified as desired (example: 'The name', not 'the_name')
      #
      # Examples:
      #   human /_cnt$/i, '\1_count'
      #   human "legacy_col_person_name", "Name"
      def human(rule, replacement)
        @humans.insert(0, [rule, replacement])
      end

      # Clears the loaded inflections within a given scope (default is <tt>:all</tt>).
      # Give the scope as a symbol of the inflection type, the options are: <tt>:plurals</tt>,
      # <tt>:singulars</tt>, <tt>:uncountables</tt>, <tt>:humans</tt>.
      #
      # Examples:
      #   clear :all
      #   clear :plurals
      def clear(scope = :all)
        case scope
          when :all
            @plurals, @singulars, @uncountables = [], [], []
          else
            instance_variable_set "@#{scope}", []
        end
      end
    end

    # Yields a singleton instance of Inflector::Inflections so you can specify additional
    # inflector rules.
    #
    # Example:
    #   ActiveSupport::Inflector.inflections do |inflect|
    #     inflect.uncountable "rails"
    #   end
    def inflections
      if block_given?
        yield Inflections.instance
      else
        Inflections.instance
      end
    end

    # Returns the plural form of the word in the string.
    #
    # Examples:
    #   "post".pluralize             # => "posts"
    #   "octopus".pluralize          # => "octopi"
    #   "sheep".pluralize            # => "sheep"
    #   "words".pluralize            # => "words"
    #   "CamelOctopus".pluralize     # => "CamelOctopi"
    def pluralize(word)
      result = word.to_s.dup

      if word.empty? || inflections.uncountables.include?(result.downcase)
        result
      else
        inflections.plurals.each { |(rule, replacement)| break if result.gsub!(rule, replacement) }
        result
      end
    end

    # The reverse of +pluralize+, returns the singular form of a word in a string.
    #
    # Examples:
    #   "posts".singularize            # => "post"
    #   "octopi".singularize           # => "octopus"
    #   "sheep".singluarize            # => "sheep"
    #   "word".singularize             # => "word"
    #   "CamelOctopi".singularize      # => "CamelOctopus"
    def singularize(word)
      result = word.to_s.dup

      if inflections.uncountables.include?(result.downcase)
        result
      else
        inflections.singulars.each { |(rule, replacement)| break if result.gsub!(rule, replacement) }
        result
      end
    end

    # By default, +camelize+ converts strings to UpperCamelCase. If the argument to +camelize+
    # is set to <tt>:lower</tt> then +camelize+ produces lowerCamelCase.
    #
    # +camelize+ will also convert '/' to '::' which is useful for converting paths to namespaces.
    #
    # Examples:
    #   "active_record".camelize                # => "ActiveRecord"
    #   "active_record".camelize(:lower)        # => "activeRecord"
    #   "active_record/errors".camelize         # => "ActiveRecord::Errors"
    #   "active_record/errors".camelize(:lower) # => "activeRecord::Errors"
    def camelize(lower_case_and_underscored_word, first_letter_in_uppercase = true)
      if first_letter_in_uppercase
        lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
      else
        lower_case_and_underscored_word.first.downcase + camelize(lower_case_and_underscored_word)[1..-1]
      end
    end

    # Capitalizes all the words and replaces some characters in the string to create
    # a nicer looking title. +titleize+ is meant for creating pretty output. It is not
    # used in the Rails internals.
    #
    # +titleize+ is also aliased as as +titlecase+.
    #
    # Examples:
    #   "man from the boondocks".titleize # => "Man From The Boondocks"
    #   "x-men: the last stand".titleize  # => "X Men: The Last Stand"
    def titleize(word)
      humanize(underscore(word)).gsub(/\b('?[a-z])/) { $1.capitalize }
    end

    # The reverse of +camelize+. Makes an underscored, lowercase form from the expression in the string.
    #
    # Changes '::' to '/' to convert namespaces to paths.
    #
    # Examples:
    #   "ActiveRecord".underscore         # => "active_record"
    #   "ActiveRecord::Errors".underscore # => active_record/errors
    def underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end

    # Replaces underscores with dashes in the string.
    #
    # Example:
    #   "puni_puni" # => "puni-puni"
    def dasherize(underscored_word)
      underscored_word.gsub(/_/, '-')
    end

    # Capitalizes the first word and turns underscores into spaces and strips a
    # trailing "_id", if any. Like +titleize+, this is meant for creating pretty output.
    #
    # Examples:
    #   "employee_salary" # => "Employee salary"
    #   "author_id"       # => "Author"
    def humanize(lower_case_and_underscored_word)
      result = lower_case_and_underscored_word.to_s.dup

      inflections.humans.each { |(rule, replacement)| break if result.gsub!(rule, replacement) }
      result.gsub(/_id$/, "").gsub(/_/, " ").capitalize
    end

    # Removes the module part from the expression in the string.
    #
    # Examples:
    #   "ActiveRecord::CoreExtensions::String::Inflections".demodulize # => "Inflections"
    #   "Inflections".demodulize                                       # => "Inflections"
    def demodulize(class_name_in_module)
      class_name_in_module.to_s.gsub(/^.*::/, '')
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
      re_sep = Regexp.escape(sep)
      # replace accented chars with ther ascii equivalents
      parameterized_string = transliterate(string)
      # Turn unwanted chars into the seperator
      parameterized_string.gsub!(/[^a-z0-9\-_\+]+/i, sep)
      # No more than one of the separator in a row.
      parameterized_string.squeeze!(sep)
      # Remove leading/trailing separator.
      parameterized_string.gsub!(/^#{re_sep}|#{re_sep}$/i, '')
      parameterized_string.downcase
    end


    # Replaces accented characters with their ascii equivalents.
    def transliterate(string)
      Iconv.iconv('ascii//ignore//translit', 'utf-8', string).to_s
    end

    if RUBY_VERSION >= '1.9'
      undef_method :transliterate
      def transliterate(string)
        warn "Ruby 1.9 doesn't support Unicode normalization yet"
        string.dup
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

    # Create the name of a table like Rails does for models to table names. This method
    # uses the +pluralize+ method on the last word in the string.
    #
    # Examples
    #   "RawScaledScorer".tableize # => "raw_scaled_scorers"
    #   "egg_and_ham".tableize     # => "egg_and_hams"
    #   "fancyCategory".tableize   # => "fancy_categories"
    def tableize(class_name)
      pluralize(underscore(class_name))
    end

    # Create a class name from a plural table name like Rails does for table names to models.
    # Note that this returns a string and not a Class. (To convert to an actual class
    # follow +classify+ with +constantize+.)
    #
    # Examples:
    #   "egg_and_hams".classify # => "EggAndHam"
    #   "posts".classify        # => "Post"
    #
    # Singular names are not handled correctly:
    #   "business".classify     # => "Busines"
    def classify(table_name)
      # strip out any leading schema name
      camelize(singularize(table_name.to_s.sub(/.*\./, '')))
    end

    # Creates a foreign key name from a class name.
    # +separate_class_name_and_id_with_underscore+ sets whether
    # the method should put '_' between the name and 'id'.
    #
    # Examples:
    #   "Message".foreign_key        # => "message_id"
    #   "Message".foreign_key(false) # => "messageid"
    #   "Admin::Post".foreign_key    # => "post_id"
    def foreign_key(class_name, separate_class_name_and_id_with_underscore = true)
      underscore(demodulize(class_name)) + (separate_class_name_and_id_with_underscore ? "_id" : "id")
    end

    # Ruby 1.9 introduces an inherit argument for Module#const_get and
    # #const_defined? and changes their default behavior.
    if Module.method(:const_get).arity == 1
      # Tries to find a constant with the name specified in the argument string:
      #
      #   "Module".constantize     # => Module
      #   "Test::Unit".constantize # => Test::Unit
      #
      # The name is assumed to be the one of a top-level constant, no matter whether
      # it starts with "::" or not. No lexical context is taken into account:
      #
      #   C = 'outside'
      #   module M
      #     C = 'inside'
      #     C               # => 'inside'
      #     "C".constantize # => 'outside', same as ::C
      #   end
      #
      # NameError is raised when the name is not in CamelCase or the constant is
      # unknown.
      def constantize(camel_cased_word)
        names = camel_cased_word.split('::')
        names.shift if names.empty? || names.first.empty?

        constant = Object
        names.each do |name|
          constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
        end
        constant
      end
    else
      def constantize(camel_cased_word) #:nodoc:
        names = camel_cased_word.split('::')
        names.shift if names.empty? || names.first.empty?

        constant = Object
        names.each do |name|
          constant = constant.const_get(name, false) || constant.const_missing(name)
        end
        constant
      end
    end

    # Turns a number into an ordinal string used to denote the position in an
    # ordered sequence such as 1st, 2nd, 3rd, 4th.
    #
    # Examples:
    #   ordinalize(1)     # => "1st"
    #   ordinalize(2)     # => "2nd"
    #   ordinalize(1002)  # => "1002nd"
    #   ordinalize(1003)  # => "1003rd"
    def ordinalize(number)
      if (11..13).include?(number.to_i % 100)
        "#{number}th"
      else
        case number.to_i % 10
          when 1; "#{number}st"
          when 2; "#{number}nd"
          when 3; "#{number}rd"
          else    "#{number}th"
        end
      end
    end
  end
end

# in case active_support/inflector is required without the rest of active_support
require 'active_support/inflections'
require 'active_support/core_ext/string/inflections'
unless String.included_modules.include?(ActiveSupport::CoreExtensions::String::Inflections)
  String.send :include, ActiveSupport::CoreExtensions::String::Inflections
end
