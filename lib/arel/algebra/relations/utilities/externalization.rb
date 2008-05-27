module Arel
  class Externalization < Compound
    attributes :relation
    deriving :initialize, :==

    def wheres
      []
    end

    def attributes
      @attributes ||= relation.attributes.collect { |a| a.to_attribute(self) }
    end
  end

  class Relation
    def externalize
      @externalized ||= externalizable?? Externalization.new(self) : self
    end

    def externalizable?
      false
    end
  end
end
