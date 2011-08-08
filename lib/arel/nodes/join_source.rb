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

      def empty?
        !left && right.empty?
      end
    end
  end
end
