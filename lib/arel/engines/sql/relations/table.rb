module Arel
  class Table
    include Relation, Recursion::BaseCase

    cattr_accessor :engine, :tables
    attr_reader :name, :engine, :table_alias, :options

    def initialize(name, options = {})
      @name = name.to_s
      @table_exists = nil

      if options.is_a?(Hash)
        @options = options
        @engine = options[:engine] || Table.engine
        @table_alias = options[:as].to_s if options[:as].present? && options[:as].to_s != @name
      else
        @engine = options # Table.new('foo', engine)
      end

      if @engine.connection
        begin
          require "arel/engines/sql/compilers/#{@engine.adapter_name.downcase}_compiler"
          @@tables ||= engine.tables
        rescue LoadError
          raise "#{@engine.adapter_name} is not supported by Arel."
        end
      end
    end

    def as(table_alias)
      Table.new(name, options.merge(:as => table_alias))
    end

    def table_exists?
      if @table_exists
        true
      else
        @table_exists = @@tables.include?(name) || engine.table_exists?(name)
      end
    end

    def attributes
      return @attributes if defined?(@attributes)
      if table_exists?
        @attributes ||= begin
          attrs = columns.collect do |column|
            Sql::Attributes.for(column).new(column, self, column.name.to_sym)
          end
          Header.new(attrs)
        end
      else
        Header.new
      end
    end

    def eql?(other)
      self == other
    end

    def hash
      @hash ||= :name.hash
    end

    def column_for(attribute)
      has_attribute?(attribute) and columns.detect { |c| c.name == attribute.name.to_s }
    end

    def columns
      @columns ||= engine.columns(name, "#{name} Columns")
    end

    def reset
      @columns = nil
      @attributes = Header.new([])
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

