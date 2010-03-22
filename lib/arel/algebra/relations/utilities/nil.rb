require 'singleton'

module Arel
  class Nil
    include Relation, Singleton
  end
end
