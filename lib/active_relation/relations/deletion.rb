module ActiveRelation
  class Deletion < Compound
    def initialize(relation)
      @relation = relation
    end

    def to_sql(strategy = nil)
      [
        "DELETE",
        "FROM #{table_sql}",
        ("WHERE #{selects.collect(&:to_sql).join('\n\tAND ')}" unless selects.blank?)
      ].compact.join("\n")
    end
    
    def ==(other)
      self.class  == other.class    and
      relation    == other.relation
    end
  end
end