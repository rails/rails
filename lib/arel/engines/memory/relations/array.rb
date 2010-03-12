module Arel
  class Array < Relation
    attributes :array,  :attribute_names_and_types
    include Recursion::BaseCase
    deriving :==, :initialize

    def initialize(array, attribute_names_and_types)
      @array, @attribute_names_and_types = array, attribute_names_and_types
    end

    def engine
      @engine ||= Memory::Engine.new
    end

    def attributes
      @attributes ||= @attribute_names_and_types.collect do |attribute, type|
        attribute = type.new(self, attribute) if Symbol === attribute
        attribute
      end
    end

    def format(attribute, value)
      value
    end

    def eval
      @array.collect { |r| Row.new(self, r) }
    end
  end
end
