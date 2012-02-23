module Arel
  module Nodes
    class SelectCore < Arel::Nodes::Node
      attr_accessor :top, :projections, :wheres, :groups, :windows
      attr_accessor :having, :source, :set_quantifier

      def initialize
        @source         = JoinSource.new nil
        @top            = nil

        # http://savage.net.au/SQL/sql-92.bnf.html#set%20quantifier
        @set_quantifier = nil
        @projections    = []
        @wheres         = []
        @groups         = []
        @having         = nil
        @windows        = []
      end

      def from
        @source.left
      end

      def from= value
        @source.left = value
      end

      alias :froms= :from=
      alias :froms :from

      def initialize_copy other
        super
        @source      = @source.clone if @source
        @projections = @projections.clone
        @wheres      = @wheres.clone
        @groups      = @groups.clone
        @having      = @having.clone if @having
        @windows     = @windows.clone
      end
    end
  end
end
