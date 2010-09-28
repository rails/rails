module Arel
  class Table
    include Arel::Crud

    @engine = nil
    class << self; attr_accessor :engine; end

    attr_accessor :name, :engine, :aliases, :table_alias

    def initialize name, engine = Table.engine
      @name    = name
      @engine  = engine
      @columns = nil
      @aliases = []
      @table_alias = nil
      @primary_key = nil

      if Hash === engine
        @engine  = engine[:engine] || Table.engine
        @columns = attributes_for engine[:columns]

        # Sometime AR sends an :as parameter to table, to let the table know
        # that it is an Alias.  We may want to override new, and return a
        # TableAlias node?
        @table_alias = engine[:as] unless engine[:as].to_s == name.to_s
      end
    end

    def primary_key
      @primary_key ||= begin
        primary_key_name = @engine.connection.primary_key(name)
        # some tables might be without primary key
        primary_key_name && self[primary_key_name]
      end
    end

    def alias
      Nodes::TableAlias.new("#{name}_2", self).tap do |node|
        @aliases << node
      end
    end

    def from table
      SelectManager.new(@engine, table)
    end

    def joins manager
      nil
    end

    def join relation, klass = Nodes::InnerJoin
      return select_manager unless relation

      sm = SelectManager.new(@engine)
      case relation
      when String, Nodes::SqlLiteral
        raise if relation.blank?
        sm.from Nodes::StringJoin.new(self, relation)
      else
        sm.from klass.new(self, relation, nil)
      end
    end

    def group *columns
      select_manager.group(*columns)
    end

    def order *expr
      select_manager.order(*expr)
    end

    def where condition
      select_manager.where condition
    end

    def project *things
      select_manager.project(*things)
    end

    def take amount
      select_manager.take amount
    end

    def having expr
      select_manager.having expr
    end

    def columns
      @columns ||=
        attributes_for @engine.connection.columns(@name, "#{@name} Columns")
    end

    def [] name
      return nil unless table_exists?

      name = name.to_sym
      columns.find { |column| column.name == name }
    end

    private
    def select_manager
      SelectManager.new(@engine, self)
    end

    def attributes_for columns
      return nil unless columns

      columns.map do |column|
        Attributes.for(column).new self, column.name.to_sym, column
      end
    end

    def table_exists?
      @table_exists ||= tables.key?(@name) || engine.connection.table_exists?(name)
    end

    def tables
      self.class.table_cache(@engine)
    end

    @@table_cache = nil
    def self.table_cache engine # :nodoc:
      @@table_cache ||= Hash[engine.connection.tables.map { |x| [x,true] }]
    end
  end
end
