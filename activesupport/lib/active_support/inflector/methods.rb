require 'active_support/inflector/inflections'

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

    # Returns the plural form of the word in the string.
    #
    # Examples:
    #   "post".pluralize             # => "posts"
    #   "octopus".pluralize          # => "octopi"
    #   "sheep".pluralize            # => "sheep"
    #   "words".pluralize            # => "words"
    #   "CamelOctopus".pluralize     # => "CamelOctopi"
    def pluralize(word)
      apply_inflections(word, inflections.plurals)
    end

    # The reverse of +pluralize+, returns the singular form of a word in a string.
    #
    # Examples:
    #   "posts".singularize            # => "post"
    #   "octopi".singularize           # => "octopus"
    #   "sheep".singularize            # => "sheep"
    #   "word".singularize             # => "word"
    #   "CamelOctopi".singularize      # => "CamelOctopus"
    def singularize(word)
      apply_inflections(word, inflections.singulars)
    end

    # By default, +camelize+ converts strings to UpperCamelCase. If the argument to +camelize+
    # is set to <tt>:lower</tt> then +camelize+ produces lowerCamelCase.
    #
    # +camelize+ will also convert '/' to '::' which is useful for converting paths to namespaces.
    #
    # Examples:
    #   "active_model".camelize                # => "ActiveModel"
    #   "active_model".camelize(:lower)        # => "activeModel"
    #   "active_model/errors".camelize         # => "ActiveModel::Errors"
    #   "active_model/errors".camelize(:lower) # => "activeModel::Errors"
    #
    # As a rule of thumb you can think of +camelize+ as the inverse of +underscore+,
    # though there are cases where that does not hold:
    #
    #   "SSLError".underscore.camelize # => "SslError"
    def camelize(term, uppercase_first_letter = true)
      string = term.to_s
      if uppercase_first_letter
        string = string.sub(/^[a-z\d]*/) { inflections.acronyms[$&] || $&.capitalize }
      else
        string = string.sub(/^(?:#{inflections.acronym_regex}(?=\b|[A-Z_])|\w)/) { $&.downcase }
      end
      string.gsub(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{inflections.acronyms[$2] || $2.capitalize}" }.gsub('/', '::')
    end

    # Makes an underscored, lowercase form from the expression in the string.
    #
    # Changes '::' to '/' to convert namespaces to paths.
    #
    # Examples:
    #   "ActiveModel".underscore         # => "active_model"
    #   "ActiveModel::Errors".underscore # => "active_model/errors"
    #
    # As a rule of thumb you can think of +underscore+ as the inverse of +camelize+,
    # though there are cases where that does not hold:
    #
    #   "SSLError".underscore.camelize # => "SslError"
    def underscore(camel_cased_word)
      word = camel_cased_word.to_s.dup
      word.gsub!(/::/, '/')
      word.gsub!(/(?:([A-Za-z\d])|^)(#{inflections.acronym_regex})(?=\b|[^a-z])/) { "#{$1}#{$1 && '_'}#{$2.downcase}" }
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
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
      result.gsub!(/_id$/, "")
      result.gsub!(/_/, ' ')
      result.gsub(/([a-z\d]*)/i) { |match|
        "#{inflections.acronyms[match] || match.downcase}"
      }.gsub(/^\w/) { $&.upcase }
    end

    # Capitalizes all the words and replaces some characters in the string to create
    # a nicer looking title. +titleize+ is meant for creating pretty output. It is not
    # used in the Rails internals.
    #
    # +titleize+ is also aliased as as +titlecase+.
    #
    # Examples:
    #   "man from the boondocks".titleize   # => "Man From The Boondocks"
    #   "x-men: the last stand".titleize    # => "X Men: The Last Stand"
    #   "TheManWithoutAPast".titleize       # => "The Man Without A Past"
    #   "raiders_of_the_lost_ark".titleize  # => "Raiders Of The Lost Ark"
    def titleize(word)
      humanize(underscore(word)).gsub(/\b('?[a-z])/) { $1.capitalize }
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

    # Replaces underscores with dashes in the string.
    #
    # Example:
    #   "puni_puni" # => "puni-puni"
    def dasherize(underscored_word)
      underscored_word.gsub(/_/, '-')
    end

    # Removes the module part from the expression in the string:
    #
    #   "ActiveRecord::CoreExtensions::String::Inflections".demodulize # => "Inflections"
    #   "Inflections".demodulize                                       # => "Inflections"
    #
    # See also +deconstantize+.
    def demodulize(path)
      path = path.to_s
      if i = path.rindex('::')
        path[(i+2)..-1]
      else
        path
      end
    end

    # Removes the rightmost segment from the constant expression in the string:
    #
    #   "Net::HTTP".deconstantize   # => "Net"
    #   "::Net::HTTP".deconstantize # => "::Net"
    #   "String".deconstantize      # => ""
    #   "::String".deconstantize    # => ""
    #   "".deconstantize            # => ""
    #
    # See also +demodulize+.
    def deconstantize(path)
      path.to_s[0...(path.rindex('::') || 0)] # implementation based on the one in facets' Module#spacename
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
          constant = constant.const_defined?(name, false) ? constant.const_get(name) : constant.const_missing(name)
        end
        constant
      end
    end

    # Tries to find a constant with the name specified in the argument string:
    #
    #   "Module".safe_constantize     # => Module
    #   "Test::Unit".safe_constantize # => Test::Unit
    #
    # The name is assumed to be the one of a top-level constant, no matter whether
    # it starts with "::" or not. No lexical context is taken into account:
    #
    #   C = 'outside'
    #   module M
    #     C = 'inside'
    #     C                    # => 'inside'
    #     "C".safe_constantize # => 'outside', same as ::C
    #   end
    #
    # nil is returned when the name is not in CamelCase or the constant (or part of it) is
    # unknown.
    #
    #   "blargle".safe_constantize  # => nil
    #   "UnknownModule".safe_constantize  # => nil
    #   "UnknownModule::Foo::Bar".safe_constantize  # => nil
    #
    def safe_constantize(camel_cased_word)
      begin
        constantize(camel_cased_word)
      rescue NameError => e
        raise unless e.message =~ /(uninitialized constant|wrong constant name) #{const_regexp(camel_cased_word)}$/ ||
          e.name.to_s == camel_cased_word.to_s
      rescue ArgumentError => e
        raise unless e.message =~ /not missing constant #{const_regexp(camel_cased_word)}\!$/
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
    #   ordinalize(-11)   # => "-11th"
    #   ordinalize(-1021) # => "-1021st"
    def ordinalize(number)
      if (11..13).include?(number.to_i.abs % 100)
        "#{number}th"
      else
        case number.to_i.abs % 10
          when 1; "#{number}st"
          when 2; "#{number}nd"
          when 3; "#{number}rd"
          else    "#{number}th"
        end
      end
    end

    private

    # Mount a regular expression that will match part by part of the constant.
    # For instance, Foo::Bar::Baz will generate Foo(::Bar(::Baz)?)?
    def const_regexp(camel_cased_word) #:nodoc:
      parts = camel_cased_word.split("::")
      last  = parts.pop

      parts.reverse.inject(last) do |acc, part|
        part.empty? ? acc : "#{part}(::#{acc})?"
      end
    end

    # Applies inflection rules for +singularize+ and +pluralize+.
    #
    # Examples:
    #  apply_inflections("post", inflections.plurals) # => "posts"
    #  apply_inflections("posts", inflections.singulars) # => "post"
    def apply_inflections(word, rules)
      result = word.to_s.dup

      if word.empty? || inflections.uncountables.any? { |inflection| result =~ /\b#{inflection}\Z/i }
        result
      else
        rules.each { |(rule, replacement)| break if result.gsub!(rule, replacement) }
        result
      end
    end
  end
end
