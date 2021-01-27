# frozen_string_literal: true

module ActiveSupport
  module AbstractClass
    extend ActiveSupport::Concern

    included do
      if defined?(@root_class)
        raise AbstractClassError, "#{self} is already part of #{root_class}'s hierarchy"
      else
        @root_class = self
      end
    end

    class_methods do
      # Returns the class descending directly from the root class, or
      # an abstract class, if any, in the inheritance hierarchy.
      #
      # If A extends the root class, A.base_class will return A. If B descends from A
      # through some arbitrarily deep hierarchy, B.base_class will return A.
      #
      # If B < A and C < B and if A is an abstract_class then both B.base_class
      # and C.base_class would return B as the answer since A is an abstract_class.
      def base_class
        unless self < root_class
          # TODO: Use a different error class. Can we do this without breaking backwards compatibility?
          raise ActiveRecordError, "#{name} doesn't belong in a hierarchy descending from #{root_class}"
        end

        if superclass == root_class || superclass.abstract_class?
          self
        else
          superclass.base_class
        end
      end

      # Returns whether the class is a base class.
      # See #base_class for more information.
      def base_class?
        base_class == self
      end

      # Set this to +true+ if this is an abstract class (see
      # <tt>abstract_class?</tt>).
      # If you are using inheritance with Active Record and don't want a class
      # to be considered as part of the STI hierarchy, you must set this to
      # true.
      # +ApplicationRecord+, for example, is generated as an abstract class.
      #
      # Consider the following default behaviour:
      #
      #   Shape = Class.new(ActiveRecord::Base)
      #   Polygon = Class.new(Shape)
      #   Square = Class.new(Polygon)
      #
      #   Shape.table_name   # => "shapes"
      #   Polygon.table_name # => "shapes"
      #   Square.table_name  # => "shapes"
      #   Shape.create!      # => #<Shape id: 1, type: nil>
      #   Polygon.create!    # => #<Polygon id: 2, type: "Polygon">
      #   Square.create!     # => #<Square id: 3, type: "Square">
      #
      # However, when using <tt>abstract_class</tt>, +Shape+ is omitted from
      # the hierarchy:
      #
      #   class Shape < ActiveRecord::Base
      #     self.abstract_class = true
      #   end
      #   Polygon = Class.new(Shape)
      #   Square = Class.new(Polygon)
      #
      #   Shape.table_name   # => nil
      #   Polygon.table_name # => "polygons"
      #   Square.table_name  # => "polygons"
      #   Shape.create!      # => NotImplementedError: Shape is an abstract class and cannot be instantiated.
      #   Polygon.create!    # => #<Polygon id: 1, type: nil>
      #   Square.create!     # => #<Square id: 2, type: "Square">
      #
      # Note that in the above example, to disallow the creation of a plain
      # +Polygon+, you should use <tt>validates :type, presence: true</tt>,
      # instead of setting it as an abstract class. This way, +Polygon+ will
      # stay in the hierarchy, and Active Record will continue to correctly
      # derive the table name.
      #
      # TODO: Move this documentation somewhere else
      attr_accessor :abstract_class

      # Returns whether this class is an abstract class or not.
      def abstract_class?
        defined?(@abstract_class) && @abstract_class == true
      end

      private

      # TODO: Should these be part of the public API?
      attr_reader :root_class

      def root_class?
        root_class == self
      end
    end
  end
end
