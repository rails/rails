module Arel
  class Take < Compound
    attributes :relation, :taken
    deriving :initialize, :==
    
    def externalizable?
      true
    end
  end
end