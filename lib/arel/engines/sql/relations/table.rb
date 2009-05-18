module Arel
  class Table < Relation
    include Recursion::BaseCase

    cattr_accessor :engine
    attr_reader :name, :engine

    def initialize(name, engine = Table.engine)
      @name, @engine = name.to_s, engine
    end

    def attributes
      @attributes ||= columns.collect do |column|
        Attribute.new(self, column.name.to_sym)
      end
    end

    def eql?(other)
      self == other
    end

    def hash
      @hash ||= :name.hash
    end

    def format(attribute, value)
      attribute.column.type_cast(value)
    end

    def column_for(attribute)
      has_attribute?(attribute) and columns.detect { |c| c.name == attribute.name.to_s }
    end

    def columns
      @columns ||= engine.columns(name, "#{name} Columns")
    end

    def reset
      @attributes = @columns = nil
    end

    def ==(other)
      Table      === other and
      name       ==  other.name
    end
  end
end

def Table(name, engine = Arel::Table.engine)
  Arel::Table.new(name, engine)
end

