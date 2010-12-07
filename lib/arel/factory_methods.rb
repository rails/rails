module Arel
  ###
  # Methods for creating various nodes
  module FactoryMethods
    def create_join from, to, on = nil, klass = Nodes::InnerJoin
      klass.new(from, to, on)
    end
  end
end
