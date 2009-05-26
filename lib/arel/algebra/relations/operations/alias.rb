module Arel
  class Alias < Compound
    attributes :relation
    deriving :initialize
    alias_method :==, :equal?
  end
end
