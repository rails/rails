module Arel
  class Skip < Compound
    attributes :relation, :skipped
    deriving   :initialize, :==
    requires   :skipping
  end
end
