module Arel
  class Skip < Compound
    attributes :relation, :skipped
    deriving :initialize, :==
    
    def externalizable?
      true
    end
  end
end