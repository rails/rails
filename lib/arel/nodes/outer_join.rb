module Arel
  module Nodes
    class OuterJoin < Arel::Nodes::Join
    end
  end

  # FIXME: backwards compat
  OuterJoin = Nodes::OuterJoin
end
