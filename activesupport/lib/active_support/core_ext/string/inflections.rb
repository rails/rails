require 'active_support/inflector/methods'
require 'active_support/inflector/transliterate'

# String inflections define new methods on the String class to transform names for different purposes.
# For instance, you can figure out the name of a table from the name of a class.
#
#   'ScaleScore'.tableize # => "scale_scores"
#
class String
  # Returns the plural form of the word in the string.
  #
  # If the optional parameter +count+ is specified,
  # the singular form will be returned if <tt>count == 1</tt>.
  # For any other value of +count+ the plural will be returned.
  #
  # If the optional parameter +locale+ is specified,
  # the word will be pluralized as a word of that language.
  # By default, this parameter is set to <tt>:en</tt>.
  # You must define your own inflection rules for languages other than English.
  #
  #   'post'.pluralize             # => "posts"
  #   'octopus'.pluralize          # => "octopi"
  #   'sheep'.pluralize            # => "sheep"
  #   'words'.pluralize            # => "words"
  #   'the blue mailman'.pluralize # => "the blue mailmen"
  #   'CamelOctopus'.pluralize     # => "CamelOctopi"
  #   'apple'.pluralize(1)         # => "apple"
  #   'apple'.pluralize(2)         # => "apples"
  #   'ley'.pluralize(:es)         # => "leyes"
  #   'ley'.pluralize(1, :es)      # => "ley"
  def pluralize(count = nil, locale = :en)
    locale = count if count.is_a?(Symbol)
    if count == 1
      self.dup
    else
      ActiveSupport::Inflector.pluralize(self, locale)
    end
  end

  # The reverse of +pluralize+, returns the singular form of a word in a string.
  #
  # If the optional parameter +locale+ is specified,
  # the word will be singularized as a word of that language.
  # By default, this parameter is set to <tt>:en</tt>.
  # You must define your own inflection rules for languages other than English.
  #
  #   'posts'.singularize            # => "post"
  #   'octopi'.singularize           # => "octopus"
  #   'sheep'.singularize            # => "sheep"
  #   'word'.singularize             # => "word"
  #   'the blue mailmen'.singularize # => "the blue mailman"
  #   'CamelOctopi'.singularize      # => "CamelOctopus"
  #   'leyes'.singularize(:es)       # => "ley"
  def singularize(locale = :en)
    ActiveSupport::Inflector.singularize(self, locale)
  end

  # +constantize+ tries to find a declared constant with the name specified
  # in the string. It raises a NameError when the name is not in CamelCase
  # or is not initialized.  See ActiveSupport::Inflector.constantize
  #
  #   'Module'.constantize  # => Module
  #   'Class'.constantize   # => Class
  #   'blargle'.constantize # => NameError: wrong constant name blargle
  def constantize
    ActiveSupport::Inflector.constantize(self)
  end

  # +safe_constantize+ tries to find a declared constant with the name specified
  # in the string. It returns nil when the name is not in CamelCase
  # or is not initialized.  See ActiveSupport::Inflector.safe_constantize
  #
  #   'Module'.safe_constantize  # => Module
  #   'Class'.safe_constantize   # => Class
  #   'blargle'.safe_constantize # => nil
  def safe_constantize
    ActiveSupport::Inflector.safe_constantize(self)
  end

  # By default, +camelize+ converts strings to UpperCamelCase. If the argument to camelize
  # is set to <tt>:lower</tt> then camelize produces lowerCamelCase.
  #
  # +camelize+ will also convert '/' to '::' which is useful for converting paths to namespaces.
  #
  #   'active_record'.camelize                # => "ActiveRecord"
  #   'active_record'.camelize(:lower)        # => "activeRecord"
  #   'active_record/errors'.camelize         # => "ActiveRecord::Errors"
  #   'active_record/errors'.camelize(:lower) # => "activeRecord::Errors"
  def camelize(first_letter = :upper)
    case first_letter
    when :upper
      ActiveSupport::Inflector.camelize(self, true)
    when :lower
      ActiveSupport::Inflector.camelize(self, false)
    end
  end
  alias_method :camelcase, :camelize

  # Capitalizes all the words and replaces some characters in the string to create
  # a nicer looking title. +titleize+ is meant for creating pretty output. It is not
  # used in the Rails internals.
  #
  # +titleize+ is also aliased as +titlecase+.
  #
  #   'man from the boondocks'.titleize # => "Man From The Boondocks"
  #   'x-men: the last stand'.titleize  # => "X Men: The Last Stand"
  def titleize
    ActiveSupport::Inflector.titleize(self)
  end
  alias_method :titlecase, :titleize

  # The reverse of +camelize+. Makes an underscored, lowercase form from the expression in the string.
  #
  # +underscore+ will also change '::' to '/' to convert namespaces to paths.
  #
  #   'ActiveModel'.underscore         # => "active_model"
  #   'ActiveModel::Errors'.underscore # => "active_model/errors"
  def underscore
    ActiveSupport::Inflector.underscore(self)
  end

  # Replaces underscores with dashes in the string.
  #
  #   'puni_puni'.dasherize # => "puni-puni"
  def dasherize
    ActiveSupport::Inflector.dasherize(self)
  end

  # Removes the module part from the constant expression in the string.
  #
  #   'ActiveRecord::CoreExtensions::String::Inflections'.demodulize # => "Inflections"
  #   'Inflections'.demodulize                                       # => "Inflections"
  #   '::Inflections'.demodulize                                     # => "Inflections"
  #   ''.demodulize                                                  # => ''
  #
  # See also +deconstantize+.
  def demodulize
    ActiveSupport::Inflector.demodulize(self)
  end

  # Removes the rightmost segment from the constant expression in the string.
  #
  #   'Net::HTTP'.deconstantize   # => "Net"
  #   '::Net::HTTP'.deconstantize # => "::Net"
  #   'String'.deconstantize      # => ""
  #   '::String'.deconstantize    # => ""
  #   ''.deconstantize            # => ""
  #
  # See also +demodulize+.
  def deconstantize
    ActiveSupport::Inflector.deconstantize(self)
  end

  # Replaces special characters in a string so that it may be used as part of a 'pretty' URL.
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
  #   <%= link_to(@person.name, person_path) %>
  #   # => <a href="/person/1-donald-e-knuth">Donald E. Knuth</a>
  def parameterize(sep = '-')
    ActiveSupport::Inflector.parameterize(self, sep)
  end

  # Creates the name of a table like Rails does for models to table names. This method
  # uses the +pluralize+ method on the last word in the string.
  #
  #   'RawScaledScorer'.tableize # => "raw_scaled_scorers"
  #   'egg_and_ham'.tableize     # => "egg_and_hams"
  #   'fancyCategory'.tableize   # => "fancy_categories"
  def tableize
    ActiveSupport::Inflector.tableize(self)
  end

  # Create a class name from a plural table name like Rails does for table names to models.
  # Note that this returns a string and not a class. (To convert to an actual class
  # follow +classify+ with +constantize+.)
  #
  #   'egg_and_hams'.classify # => "EggAndHam"
  #   'posts'.classify        # => "Post"
  def classify
    ActiveSupport::Inflector.classify(self)
  end

  # Capitalizes the first word, turns underscores into spaces, and strips a
  # trailing '_id' if present.
  # Like +titleize+, this is meant for creating pretty output.
  #
  # The capitalization of the first word can be turned off by setting the
  # optional parameter +capitalize+ to false.
  # By default, this parameter is true.
  #
  #   'employee_salary'.humanize              # => "Employee salary"
  #   'author_id'.humanize                    # => "Author"
  #   'author_id'.humanize(capitalize: false) # => "author"
  #   '_id'.humanize                          # => "Id"
  def humanize(options = {})
    ActiveSupport::Inflector.humanize(self, options)
  end

  # Creates a foreign key name from a class name.
  # +separate_class_name_and_id_with_underscore+ sets whether
  # the method should put '_' between the name and 'id'.
  #
  #   'Message'.foreign_key        # => "message_id"
  #   'Message'.foreign_key(false) # => "messageid"
  #   'Admin::Post'.foreign_key    # => "post_id"
  def foreign_key(separate_class_name_and_id_with_underscore = true)
    ActiveSupport::Inflector.foreign_key(self, separate_class_name_and_id_with_underscore)
  end
end
