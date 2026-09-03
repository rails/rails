# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module ReferentialIntegrity # :nodoc:
        def disable_referential_integrity # :nodoc:
          old_foreign_keys = query_value("PRAGMA foreign_keys", nil)
          old_defer_foreign_keys = query_value("PRAGMA defer_foreign_keys", nil)

          begin
            execute("PRAGMA defer_foreign_keys = ON")
            execute("PRAGMA foreign_keys = OFF")
            yield
          ensure
            execute("PRAGMA defer_foreign_keys = #{old_defer_foreign_keys}")
            execute("PRAGMA foreign_keys = #{old_foreign_keys}")
          end
        end
      end
    end
  end
end
