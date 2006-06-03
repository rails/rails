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
        #   "sheep".pluralize #=> "sheep"
        #   "the blue mailman".pluralize #=> "the blue mailmen"
        def pluralize
          Inflector.pluralize(self)
        end

        # The reverse of pluralize, returns the singular form of a word in a string.
        #
        # Examples
        #   "posts".singularize => "post"
        #   "the blue mailmen".pluralize #=> "the blue mailman"
        def singularize
          Inflector.singularize(self)
        end

        # Creates a camelcased name from an underscored name. CamelCased names LookLikeThis and under_scored_names look_like_this.
        #
        # Examples
        #   "active_record".camelize #=> "ActiveRecord"
        #   "raw_scaled_scorer".camelize #=> "RawScaledScorer"
        def camelize(first_letter = :upper)
          case first_letter
            when :upper then Inflector.camelize(self, true)
            when :lower then Inflector.camelize(self, false)
          end
        end
        alias_method :camelcase, :camelize

        # Capitalizes all the words and replaces some characters in the string to create a nicer looking title.
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
        # Examples
        #   "ActiveRecord".underscore #=> "active_record"
        #   "RawScaledScore".underscore #=> "raw_scaled_score"
        def underscore
          Inflector.underscore(self)
        end

        # Replaces underscores with dashes in the string
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

        # Create the name of a table like Rails does for models to table names.
        #
        # Examples
        #   "RawScaledScorer".tableize #=> "raw_scaled_scorers"
        #   "egg_and_ham".tableize #=> "egg_and_hams"
        def tableize
          Inflector.tableize(self)
        end

        # Create a class name from a table name like Rails does for table names to models. Note that this returns a string and not a Class.
        #
        # Examples
        #   "egg_and_hams".classify #=> "EggAndHam"
        #   "post".classify #=> "Post"
        def classify
          Inflector.classify(self)
        end
        
        # Capitalizes the first word and turns underscores into spaces and strips _id.
        #
        # Examples
        #   "employee_salary" #=> "Employee salary" 
        #   "author_id" #=> "Author"
        def humanize
          Inflector.humanize(self)
        end

        # Creates a foreign key name from a class name. +separate_class_name_and_id_with_underscore+ sets whether the method should put '_' between the name and 'id'.
        #
        # Examples
        #   "Message".foreign_key #=> "message_id"
        #   "Message".foreign_key(false) #=> "messageid"
        #   "Admin::Post".foreign_key #=> "post_id"
        def foreign_key(separate_class_name_and_id_with_underscore = true)
          Inflector.foreign_key(self, separate_class_name_and_id_with_underscore)
        end

        # Constantize tries to find a declared constant with the name specified in the string. It raises a NameError when the name is not in CamelCase or is not initialized.
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
