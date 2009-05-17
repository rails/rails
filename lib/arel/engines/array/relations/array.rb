module Arel
  class Array < Relation
    include Recursion::BaseCase

    def initialize(array, attribute_names)
      @array, @attribute_names = array, attribute_names
    end

    def attributes
      @attributes ||= @attribute_names.collect do |name|
        Attribute.new(self, name.to_sym)
      end
    end

    def call(connection = nil)
      @array.collect { |row| attributes.zip(row).to_hash }
    end
  end
end