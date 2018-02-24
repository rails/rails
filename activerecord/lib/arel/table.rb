# frozen_string_literal: true

module Arel
  class Table
    include Arel::Crud
    include Arel::FactoryMethods

    @engine = nil
    class << self; attr_accessor :engine; end

    attr_accessor :name, :table_alias

    # TableAlias and Table both have a #table_name which is the name of the underlying table
    alias :table_name :name

    def initialize(name, as: nil, type_caster: nil)
      @name = name.to_s
      @type_caster = type_caster

      # Sometime AR sends an :as parameter to table, to let the table know
      # that it is an Alias.  We may want to override new, and return a
      # TableAlias node?
      if as.to_s == @name
        as = nil
      end
      @table_alias = as
    end

    def alias(name = "#{self.name}_2")
      Nodes::TableAlias.new(self, name)
    end

    def from
      SelectManager.new(self)
    end

    def join(relation, klass = Nodes::InnerJoin)
      return from unless relation

      case relation
      when String, Nodes::SqlLiteral
        raise EmptyJoinError if relation.empty?
        klass = Nodes::StringJoin
      end

      from.join(relation, klass)
    end

    def outer_join(relation)
      join(relation, Nodes::OuterJoin)
    end

    def group(*columns)
      from.group(*columns)
    end

    def order(*expr)
      from.order(*expr)
    end

    def where(condition)
      from.where condition
    end

    def project(*things)
      from.project(*things)
    end

    def take(amount)
      from.take amount
    end

    def skip(amount)
      from.skip amount
    end

    def having(expr)
      from.having expr
    end

    def [](name)
      ::Arel::Attribute.new self, name
    end

    def hash
      # Perf note: aliases and table alias is excluded from the hash
      #  aliases can have a loop back to this table breaking hashes in parent
      #  relations, for the vast majority of cases @name is unique to a query
      @name.hash
    end

    def eql?(other)
      self.class == other.class &&
        self.name == other.name &&
        self.table_alias == other.table_alias
    end
    alias :== :eql?

    def type_cast_for_database(attribute_name, value)
      type_caster.type_cast_for_database(attribute_name, value)
    end

    def able_to_type_cast?
      !type_caster.nil?
    end

    protected

      attr_reader :type_caster
  end
end
