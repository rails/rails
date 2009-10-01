module Arel
  module SymbolExtensions
    def to_attribute(relation)
      Arel::Attribute.new(relation, self)
    end

    Symbol.send(:include, self)
  end
end
