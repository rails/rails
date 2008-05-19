module Arel
  class Deletion < Compound
    def initialize(relation)
      @relation = relation
    end

    def to_sql(formatter = nil)
      [
        "DELETE",
        "FROM #{table_sql}",
        ("WHERE #{wheres.collect(&:to_sql).join('\n\tAND ')}" unless wheres.blank?  ),
        ("LIMIT     #{taken}"                                  unless taken.blank?    ),
      ].compact.join("\n")
    end
    
    def call(connection = engine.connection)
      connection.delete(to_sql)
    end
    
    def ==(other)
      Deletion    === other and
      relation    ==  other.relation
    end
  end
end