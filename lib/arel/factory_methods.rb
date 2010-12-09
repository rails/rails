module Arel
  ###
  # Methods for creating various nodes
  module FactoryMethods
    def create_join from, to, on = nil, klass = Nodes::InnerJoin
      klass.new(from, to, on)
    end

    def create_string_join from, to
      create_join from, to, nil, Nodes::StringJoin
    end

    def create_and clauses
      Nodes::And.new clauses
    end
  end
end
