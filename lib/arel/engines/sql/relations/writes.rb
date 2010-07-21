module Arel
  class Deletion < Action
    def to_sql
      compiler.delete_sql
    end
  end

  class Insert < Action
    def to_sql(include_returning = true)
      compiler.insert_sql(include_returning)
    end
  end

  class Update < Insert
    def to_sql
      compiler.update_sql
    end
  end
end
