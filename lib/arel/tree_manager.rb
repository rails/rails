module Arel
  class TreeManager
    # FIXME: Remove this.
    include Arel::Relation

    VISITORS = {
      'postgresql' => Arel::Visitors::PostgreSQL
    }

    def initialize engine
      @engine        = engine
      @pool          = engine.connection_pool
      @adapter       = @pool.spec.config[:adapter]
      @visitor_klass = VISITORS[@adapter] || Visitors::ToSql
    end

    def to_dot
      Visitors::Dot.new.accept @head
    end

    def to_sql
      viz = @visitor_klass.new @engine
      viz.accept @head
    end

    def initialize_copy other
      super
      @head = @head.clone
    end
  end
end
