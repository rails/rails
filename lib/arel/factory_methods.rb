module Arel
  ###
  # Methods for creating various nodes
  module FactoryMethods
    def create_join to, constraint = nil, klass = Nodes::InnerJoin
      klass.new(to, constraint)
    end

    def create_string_join from, to
      create_join from, to, Nodes::StringJoin
    end

    def create_and clauses
      Nodes::And.new clauses
    end

    def create_on expr
      Nodes::On.new expr
    end
  end
end
