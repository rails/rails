module Arel
  class Deletion < Compound
    attributes :relation
    deriving :initialize, :==

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
  end
end