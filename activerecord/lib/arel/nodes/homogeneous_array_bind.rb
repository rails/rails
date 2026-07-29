# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    # A homogeneous IN/NOT IN predicate that adapters may compile as a single
    # array bind parameter (PostgreSQL: +col = ANY($1)+ / +col <> ALL($1)+)
    # instead of expanding every value into +IN (1, 2, ..., N)+.
    #
    # Built via +Arel.array_bind+ through
    # +ActiveRecord::PredicateBuilder::ArrayBindHandler+.
    class HomogeneousArrayBind < HomogeneousIn
    end
  end
end
