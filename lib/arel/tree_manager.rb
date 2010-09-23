module Arel
  class TreeManager
    # FIXME: Remove this.
    include Arel::Relation

    VISITORS = {
      'postgresql' => Arel::Visitors::PostgreSQL,
      'mysql'      => Arel::Visitors::MySQL,
      'mysql2'     => Arel::Visitors::MySQL,
    }

    attr_accessor :visitor

    def initialize engine
      @engine  = engine
      @visitor = nil
    end

    def to_dot
      Visitors::Dot.new.accept @head
    end

    def visitor
      return @visitor if @visitor
      pool          = @engine.connection_pool
      adapter       = pool.spec.config[:adapter]
      @visitor = (VISITORS[adapter] || Visitors::ToSql).new(@engine)
    end

    def to_sql
      visitor.accept @head
    end

    def initialize_copy other
      super
      @head = @head.clone
    end
  end
end
