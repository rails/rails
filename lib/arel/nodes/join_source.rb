module Arel
  module Nodes
    ###
    # Class that represents a join source
    #
    #   http://www.sqlite.org/syntaxdiagrams.html#join-source

    class JoinSource < Arel::Nodes::Binary
      def initialize single_source, joinop = []
        super
      end

      def initialize_copy other
        super
        @left  = @left.clone if @left
        @right = @right.clone if @right
      end
    end
  end
end
