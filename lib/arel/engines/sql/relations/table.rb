module Arel
  class Table
    include Relation, Recursion::BaseCase

    @@engine = nil
    @@tables = nil
    class << self # FIXME: Do we really need these?
      def engine; @@engine; end
      def engine= e; @@engine = e; end

      def tables; @@tables; end
      def tables= e; @@tables = e; end
    end

    attr_reader :name, :engine, :table_alias, :options, :christener
    attr_reader :table_exists
    alias :table_exists? :table_exists

    def initialize(name, options = {})
      @name = name.to_s
      @table_exists = nil
      @table_alias = nil
      @christener = Sql::Christener.new
      @attributes = nil
      @matching_attributes = nil

      if options.is_a?(Hash)
        @options = options
        @engine = options[:engine] || Table.engine

        if options[:as]
          as = options[:as].to_s
          @table_alias = as unless as == @name
        end
      else
        @engine = options # Table.new('foo', engine)
      end

      if @engine.connection
        begin
          require "arel/engines/sql/compilers/#{@engine.adapter_name.downcase}_compiler"
        rescue LoadError
          begin
            # try to load an externally defined compiler, in case this adapter has defined the compiler on its own.
            require "#{@engine.adapter_name.downcase}/arel_compiler"
          rescue LoadError
            raise "#{@engine.adapter_name} is not supported by Arel."
          end
        end

        @@tables ||= engine.connection.tables
        @table_exists = @@tables.include?(name) ||
          @engine.connection.table_exists?(name)
      end
    end

    def as(table_alias)
      Table.new(name, options.merge(:as => table_alias))
    end

    def attributes
      return @attributes if @attributes
      if table_exists?
        attrs = columns.collect do |column|
          Sql::Attributes.for(column).new(column, self, column.name.to_sym)
        end
        @attributes = Header.new(attrs)
      else
        Header.new
      end
    end

    def column_for(attribute)
      has_attribute?(attribute) and columns.detect { |c| c.name == attribute.name.to_s }
    end

    def columns
      @columns ||= engine.connection.columns(name, "#{name} Columns")
    end

    def reset
      @columns = nil
      @attributes = Header.new([])
    end

    private
    def matching_attributes
      @matching_attributes ||= Hash[attributes.map { |a| [a.root, true] }]
    end

    def has_attribute?(attribute)
      matching_attributes.key? attribute.root
    end
  end
end

def Table(name, engine = Arel::Table.engine)
  Arel::Table.new(name, engine)
end

