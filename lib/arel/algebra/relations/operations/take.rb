module Arel
  class Take < Compound
    attributes :relation, :taken
    deriving   :initialize, :==
    requires   :limiting

    def externalizable?
      true
    end
  end
end
