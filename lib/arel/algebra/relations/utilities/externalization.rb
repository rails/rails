module Arel
  class Externalization < Compound
    attributes :relation
    deriving :initialize, :==

    def wheres
      []
    end

    def attributes
      @attributes ||= Header.new(relation.attributes.map { |a| a.to_attribute(self) })
    end
  end

  module Relation
    def externalize
      @externalized ||= externalizable?? Externalization.new(self) : self
    end

    def externalizable?
      false
    end
  end
end
