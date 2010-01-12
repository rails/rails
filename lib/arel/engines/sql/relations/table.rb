module Arel
  class Table < Relation
    include Recursion::BaseCase

    cattr_accessor :engine
    attr_reader :name, :engine, :table_alias, :options

    def initialize(name, options = {})
      @name = name.to_s

      if options.is_a?(Hash)
        @options = options
        @engine = options[:engine] || Table.engine
        @table_alias = options[:as].to_s if options[:as].present? && options[:as].to_s != @name
      else
        @engine = options # Table.new('foo', engine)
      end
    end

    def as(table_alias)
      Table.new(name, options.merge(:as => table_alias))
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
      Table       === other and
      name        ==  other.name and
      table_alias ==  other.table_alias
    end
  end
end

def Table(name, engine = Arel::Table.engine)
  Arel::Table.new(name, engine)
end

