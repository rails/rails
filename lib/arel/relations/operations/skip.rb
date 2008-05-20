module Arel
  class Skip < Compound
    attributes :relation, :skipped
    deriving :initialize, :==
  end
end