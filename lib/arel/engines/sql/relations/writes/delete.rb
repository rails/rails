module Arel
  class Deletion < Compound
    def to_sql(formatter = nil)
      [
        "DELETE",
        "FROM #{table_sql}",
        ("WHERE #{wheres.collect(&:to_sql).join('\n\tAND ')}" unless wheres.blank?  ),
        ("LIMIT #{taken}"                                     unless taken.blank?    ),
      ].compact.join("\n")
    end
  end
end