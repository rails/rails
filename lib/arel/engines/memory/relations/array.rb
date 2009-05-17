module Arel
  class Array < Relation
    attributes :array,  :attribute_names
    deriving :initialize
    include Recursion::BaseCase
    
    def engine
      @engine ||= Memory::Engine.new
    end

    def attributes
      @attributes ||= @attribute_names.collect do |name|
        Attribute.new(self, name.to_sym)
      end
    end

    def eval
      @array.collect { |r| Row.new(self, r) }
    end
  end
end