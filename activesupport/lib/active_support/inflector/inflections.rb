module ActiveSupport
  module Inflector
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
      def self.instance
        @__instance__ ||= new
      end

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
          plural(Regexp.new("(#{plural[0,1]})#{plural[1..-1]}$", "i"), '\1' + plural[1..-1])
          singular(Regexp.new("(#{plural[0,1]})#{plural[1..-1]}$", "i"), '\1' + singular[1..-1])
        else
          plural(Regexp.new("#{singular[0,1].upcase}(?i)#{singular[1..-1]}$"), plural[0,1].upcase + plural[1..-1])
          plural(Regexp.new("#{singular[0,1].downcase}(?i)#{singular[1..-1]}$"), plural[0,1].downcase + plural[1..-1])
          plural(Regexp.new("#{plural[0,1].upcase}(?i)#{plural[1..-1]}$"), plural[0,1].upcase + plural[1..-1])
          plural(Regexp.new("#{plural[0,1].downcase}(?i)#{plural[1..-1]}$"), plural[0,1].downcase + plural[1..-1])
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
    #   "sheep".singularize            # => "sheep"
    #   "word".singularize             # => "word"
    #   "CamelOctopi".singularize      # => "CamelOctopus"
    def singularize(word)
      result = word.to_s.dup

      if inflections.uncountables.any? { |inflection| result =~ /#{inflection}\Z/i }
        result
      else
        inflections.singulars.each { |(rule, replacement)| break if result.gsub!(rule, replacement) }
        result
      end
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
  end
end
