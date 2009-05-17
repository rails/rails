module Arel
  class Array < Relation
    attributes :array,  :attribute_names
    include Recursion::BaseCase
    deriving :==, :initialize

    def engine
      @engine ||= Memory::Engine.new
    end

    def attributes
      @attributes ||= @attribute_names.collect do |name|
        name.to_attribute(self)
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
