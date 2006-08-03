require File.dirname(__FILE__) + '/../../inflector' unless defined? Inflector

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      # String inflections define new methods on the String class to transform names for different purposes.
      # For instance, you can figure out the name of a database from the name of a class.
      #   "ScaleScore".tableize => "scale_scores"
      module Inflections
        # Returns the plural form of the word in the string.
        #
        # Examples
        #   "post".pluralize #=> "posts"
        #   "octopus".pluralize #=> "octopi"
        #   "sheep".pluralize #=> "sheep"
        #   "words".pluralize #=> "words"
        #   "the blue mailman".pluralize #=> "the blue mailmen"
        #   "CamelOctopus".pluralize #=> "CamelOctopi"
        def pluralize
          Inflector.pluralize(self)
        end

        # The reverse of pluralize, returns the singular form of a word in a string.
        #
        # Examples
        #   "posts".singularize #=> "post"
        #   "octopi".singularize #=> "octopus"
        #   "sheep".singluarize #=> "sheep"
        #   "word".singluarize #=> "word"
        #   "the blue mailmen".singularize #=> "the blue mailman"
        #   "CamelOctopi".singularize #=> "CamelOctopus"
        def singularize
          Inflector.singularize(self)
        end

        # By default, camelize converts strings to UpperCamelCase. If the argument to camelize
        # is set to ":lower" then camelize produces lowerCamelCase.
        #
        # camelize will also convert '/' to '::' which is useful for converting paths to namespaces 
        #
        # Examples
        #   "active_record".camelize #=> "ActiveRecord"
        #   "active_record".camelize(:lower) #=> "activeRecord"
        #   "active_record/errors".camelize #=> "ActiveRecord::Errors"
        #   "active_record/errors".camelize(:lower) #=> "activeRecord::Errors"
        def camelize(first_letter = :upper)
          case first_letter
            when :upper then Inflector.camelize(self, true)
            when :lower then Inflector.camelize(self, false)
          end
        end
        alias_method :camelcase, :camelize

        # Capitalizes all the words and replaces some characters in the string to create
        # a nicer looking title. Titleize is meant for creating pretty output. It is not
        # used in the Rails internals.
        #
        # titleize is also aliased as as titlecase
        #
        # Examples
        #   "man from the boondocks".titleize #=> "Man From The Boondocks"
        #   "x-men: the last stand".titleize #=> "X Men: The Last Stand"
        def titleize
          Inflector.titleize(self)
        end
        alias_method :titlecase, :titleize

        # The reverse of +camelize+. Makes an underscored form from the expression in the string.
        # 
        # Changes '::' to '/' to convert namespaces to paths.
        #
        # Examples
        #   "ActiveRecord".underscore #=> "active_record"
        #   "ActiveRecord::Errors".underscore #=> active_record/errors
        def underscore
          Inflector.underscore(self)
        end

        # Replaces underscores with dashes in the string.
        #
        # Example
        #   "puni_puni" #=> "puni-puni"
        def dasherize
          Inflector.dasherize(self)
        end

        # Removes the module part from the expression in the string
        #
        # Examples
        #   "ActiveRecord::CoreExtensions::String::Inflections".demodulize #=> "Inflections"
        #   "Inflections".demodulize #=> "Inflections"
        def demodulize
          Inflector.demodulize(self)
        end

        # Create the name of a table like Rails does for models to table names. This method
        # uses the pluralize method on the last word in the string.
        #
        # Examples
        #   "RawScaledScorer".tableize #=> "raw_scaled_scorers"
        #   "egg_and_ham".tableize #=> "egg_and_hams"
        #   "fancyCategory".tableize #=> "fancy_categories"
        def tableize
          Inflector.tableize(self)
        end

        # Create a class name from a table name like Rails does for table names to models.
        # Note that this returns a string and not a Class. (To convert to an actual class
        # follow classify with constantize.)
        #
        # Examples
        #   "egg_and_hams".classify #=> "EggAndHam"
        #   "post".classify #=> "Post"
        def classify
          Inflector.classify(self)
        end
        
        # Capitalizes the first word and turns underscores into spaces and strips _id.
        # Like titleize, this is meant for creating pretty output.
        #
        # Examples
        #   "employee_salary" #=> "Employee salary" 
        #   "author_id" #=> "Author"
        def humanize
          Inflector.humanize(self)
        end

        # Creates a foreign key name from a class name.
        # +separate_class_name_and_id_with_underscore+ sets whether
        # the method should put '_' between the name and 'id'.
        #
        # Examples
        #   "Message".foreign_key #=> "message_id"
        #   "Message".foreign_key(false) #=> "messageid"
        #   "Admin::Post".foreign_key #=> "post_id"
        def foreign_key(separate_class_name_and_id_with_underscore = true)
          Inflector.foreign_key(self, separate_class_name_and_id_with_underscore)
        end

        # Constantize tries to find a declared constant with the name specified
        # in the string. It raises a NameError when the name is not in CamelCase
        # or is not initialized.
        #
        # Examples
        #   "Module".constantize #=> Module
        #   "Class".constantize #=> Class
        def constantize
          Inflector.constantize(self)
        end
      end
    end
  end
end
