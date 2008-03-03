module ActiveRelation
  class Insertion < Compound
    attr_reader :record

    def initialize(relation, record)
      @relation, @record = relation, record
    end

    def to_sql(strategy = nil)
      [
        "INSERT",
        "INTO #{table_sql}",
        "(#{record.keys.collect(&:to_sql).join(', ')})",
        "VALUES #{record.values.to_sql}"
      ].join("\n")
    end
    
    def ==(other)
      self.class  == other.class    and
      relation    == other.relation and
      record      == other.record
    end
  end
end