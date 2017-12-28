# frozen_string_literal: true
module Arel
  module Nodes
    class SelectCore < Arel::Nodes::Node
      attr_accessor :top, :projections, :wheres, :groups, :windows
      attr_accessor :havings, :source, :set_quantifier

      def initialize
        super()
        @source         = JoinSource.new nil
        @top            = nil

        # https://ronsavage.github.io/SQL/sql-92.bnf.html#set%20quantifier
        @set_quantifier = nil
        @projections    = []
        @wheres         = []
        @groups         = []
        @havings        = []
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
        @havings     = @havings.clone
        @windows     = @windows.clone
      end

      def hash
        [
          @source, @top, @set_quantifier, @projections,
          @wheres, @groups, @havings, @windows
        ].hash
      end

      def eql? other
        self.class == other.class &&
          self.source == other.source &&
          self.top == other.top &&
          self.set_quantifier == other.set_quantifier &&
          self.projections == other.projections &&
          self.wheres == other.wheres &&
          self.groups == other.groups &&
          self.havings == other.havings &&
          self.windows == other.windows
      end
      alias :== :eql?
    end
  end
end
