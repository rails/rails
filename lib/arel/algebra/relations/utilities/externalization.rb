module Arel
  class Externalization < Compound
    def == other
      super || Externalization === other && relation == other.relation
    end

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
