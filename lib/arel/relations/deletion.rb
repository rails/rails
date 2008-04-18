module Arel
  class Deletion < Writing
    def initialize(relation)
      @relation = relation
    end

    def to_sql(formatter = nil)
      [
        "DELETE",
        "FROM #{table_sql}",
        ("WHERE #{selects.collect(&:to_sql).join('\n\tAND ')}" unless selects.blank?  ),
        ("LIMIT     #{taken}"                                  unless taken.blank?    ),
      ].compact.join("\n")
    end
    
    def call(connection = engine.connection)
      connection.delete(to_sql)
    end
    
    def ==(other)
      self.class  == other.class    and
      relation    == other.relation
    end
  end
end