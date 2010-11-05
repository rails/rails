module Arel
  class TreeManager
    # FIXME: Remove this.
    include Arel::Relation

    attr_accessor :visitor
    attr_reader :ast, :engine

    def initialize engine
      @engine  = engine
      @visitor = Visitors.visitor_for @engine
    end

    def to_dot
      Visitors::Dot.new.accept @ast
    end

    def to_sql
      @visitor.accept @ast
    end

    def initialize_copy other
      super
      @ast = @ast.clone
    end
  end
end
