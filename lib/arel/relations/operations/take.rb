module Arel
  class Take < Compound
    attributes :relation, :taken
    deriving :initialize, :==
  end
end