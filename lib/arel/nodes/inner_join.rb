module Arel
  module Nodes
    class InnerJoin < Arel::Nodes::Join
    end
  end

  # FIXME: backwards compat
  InnerJoin = Nodes::InnerJoin
end
