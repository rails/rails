# frozen_string_literal: true

module ActiveRecord
  # = Active Record Pattern Matching
  module PatternMatching
    # Provides the pattern matching interface for an Active Record model.
    module Record
      # Returns a hash of attributes for the given keys. Provides the pattern
      # matching interface for matching against hash patterns. For example:
      #
      #   class Person < ActiveRecord::Base
      #   end
      #
      #   def greeting_for(person)
      #     case person
      #     in { name: "Mary" }
      #       "Welcome back, Mary!"
      #     in { name: }
      #       "Welcome, stranger!"
      #     end
      #   end
      #
      #   person = Person.new
      #   person.name = "Mary"
      #   greeting_for(person) # => "Welcome back, Mary!"
      #
      #   person = Person.new
      #   person.name = "Bob"
      #   greeting_for(person) # => "Welcome, stranger!"
      def deconstruct_keys(keys)
        deconstructed = {}

        keys.each do |key|
          method = key.to_s

          if attribute_method?(method)
            # Here we're pattern matching against an attribute method. We're
            # going to use the [] method so that we either get the value or
            # raise an error for a missing attribute in case it wasn't loaded.
            deconstructed[key] = self[method]
          elsif self.class.reflect_on_association(method)
            # Here we're going to pattern match against an association. We're
            # going to use the main interface for that association which can be
            # further pattern matched later.
            deconstructed[key] = public_send(method)
          end
        end

        deconstructed
      end
    end

    # Provides the pattern matching interface for an Active Record relation.
    module Relation
      # Returns a hash of attributes for the given keys. Provides the pattern
      # matching interface for matching against array patterns. For example:
      #
      #   class Person < ActiveRecord::Base
      #   end
      #
      #   case Person.all
      #   in []
      #     "No one is here"
      #   in [{ name: "Mary" }]
      #     "Only Mary is here"
      #   in [_]
      #     "Only one person is here"
      #   in [_, _, *]
      #     "More than one person is here"
      #   end
      #
      # Be wary when using this method with a large number of records, as it
      # will load everything into memory.
      def deconstruct
        records
      end
    end
  end
end
