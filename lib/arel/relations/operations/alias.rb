module Arel
  class Alias < Compound
    include Recursion::BaseCase
    attributes :relation
    deriving :initialize
    alias_method :==, :equal?
  end
end