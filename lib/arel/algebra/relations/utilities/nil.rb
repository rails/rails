require 'singleton'

module Arel
  class Nil < Relation
    include Singleton
  end
end
