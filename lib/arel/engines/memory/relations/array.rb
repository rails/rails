module Arel
  class Array
    include Relation

    attr_reader :array, :attribute_names_and_types
    include Recursion::BaseCase

    def initialize(array, attribute_names_and_types)
      @array                     = array
      @attribute_names_and_types = attribute_names_and_types
      @engine                    = nil
      @attributes                = nil
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
