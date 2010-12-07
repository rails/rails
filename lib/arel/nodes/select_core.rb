module Arel
  module Nodes
    class SelectCore < Arel::Nodes::Node
      attr_accessor :from, :projections, :wheres, :groups
      attr_accessor :having

      alias :froms= :from=
      alias :froms :from

      def initialize
        @from        = nil
        @projections = []
        @wheres      = []
        @groups      = []
        @having      = nil
      end

      def initialize_copy other
        super
        @from        = @from.clone if @from
        @projections = @projections.clone
        @wheres      = @wheres.clone
        @group       = @groups.clone
        @having      = @having.clone if @having
      end
    end
  end
end
