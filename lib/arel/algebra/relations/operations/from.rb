module Arel
  class From < Compound
    attributes :relation, :sources
    deriving :initialize, :==
  end
end
