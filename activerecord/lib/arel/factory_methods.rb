# frozen_string_literal: true

module Arel # :nodoc: all
  ###
  # Methods for creating various nodes
  module FactoryMethods
    def create_true
      Arel::Nodes::True.new
    end

    def create_false
      Arel::Nodes::False.new
    end

    def create_table_alias(relation, name)
      Nodes::TableAlias.new(relation, name)
    end

    def create_join(to, constraint = nil, klass = Nodes::InnerJoin)
      klass.new(to, constraint)
    end

    def create_string_join(to)
      create_join to, nil, Nodes::StringJoin
    end

    def create_and(clauses)
      Nodes::And.new clauses
    end

    def create_on(expr)
      Nodes::On.new expr
    end

    def grouping(expr)
      Nodes::Grouping.new expr
    end

    ###
    # Create a LOWER() function
    def lower(column)
      Nodes::NamedFunction.new "LOWER", [Nodes.build_quoted(column)]
    end
  end
end
