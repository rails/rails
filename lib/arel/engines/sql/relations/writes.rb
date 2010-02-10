module Arel
  class Deletion < Compound
    def to_sql
      compiler.delete_sql
    end
  end

  class Insert < Compound
    def to_sql(include_returning = true)
      compiler.insert_sql(include_returning)
    end
  end

  class Update < Compound
    def to_sql
      compiler.update_sql
    end
  end
end
