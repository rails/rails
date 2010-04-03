module Arel
  class Array
    include Relation

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
      @attributes ||= begin
        attrs = @attribute_names_and_types.collect do |attribute, type|
          attribute = type.new(self, attribute) if Symbol === attribute
          attribute
        end
        Header.new(attrs)
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
