module Arel
  class Table
    include Arel::Crud

    @engine = nil
    class << self; attr_accessor :engine; end

    attr_reader :name, :engine, :aliases, :table_alias

    def initialize name, engine = Table.engine
      @name    = name
      @engine  = engine
      @engine  = engine[:engine] if Hash === engine
      @columns = nil
      @aliases = []
      @table_alias = nil
    end

    def alias
      Nodes::TableAlias.new("#{name}_2", self).tap do |node|
        @aliases << node
      end
    end

    def tm
      SelectManager.new(@engine).from(self)
    end

    def join relation
      sm = SelectManager.new(@engine)
      case relation
      when String, Nodes::SqlLiteral
        raise if relation.blank?
        sm.from Nodes::StringJoin.new(self, relation)
      else
        sm.from Nodes::InnerJoin.new(self, relation, nil)
      end
    end

    def where condition
      tm.where condition
    end

    def project thing
      tm.project thing
    end

    def take amount
      tm.take amount
    end

    def columns
      @columns ||= @engine.connection.columns(@name, "#{@name} Columns").map do |column|
        Attributes.for(column).new self, column.name, column
      end
    end

    def [] name
      name = name.to_s
      columns.find { |column| column.name == name }
    end
  end
end
