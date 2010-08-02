module Arel
  class Where < Compound
    attr_reader :predicates

    def initialize(relation, predicates)
      super(relation)
      @predicates = predicates.map { |p| p.bind(relation) }
      @wheres = nil
    end

    def wheres
      @wheres ||= relation.wheres + predicates
    end

    def eval
      unoperated_rows.select { |row| predicates.all? { |p| p.eval(row) } }
    end

    def to_sql(formatter = nil)
      compiler.select_sql
    end
  end
end
