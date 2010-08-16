module Arel
  class TreeManager
    # FIXME: Remove this.
    include Arel::Relation

    def initialize engine
      @engine = engine
    end

    def to_dot
      Visitors::Dot.new.accept @head
    end

    def to_sql
      viz = Visitors::ToSql.new @engine
      viz.accept @head
    end
  end
end
