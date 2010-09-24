module Arel
  class TreeManager
    # FIXME: Remove this.
    include Arel::Relation

    attr_accessor :visitor

    def initialize engine
      @engine  = engine
      @visitor = Visitors.visitor_for @engine
    end

    def to_dot
      Visitors::Dot.new.accept @head
    end

    def to_sql
      @visitor.accept @head
    end

    def initialize_copy other
      super
      @head = @head.clone
    end
  end
end
