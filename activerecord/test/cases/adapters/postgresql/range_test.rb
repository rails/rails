require "cases/helper"

if ActiveRecord::Base.connection.supports_ranges?
  class PostgresqlRange < ActiveRecord::Base
    self.table_name = "postgresql_ranges"
  end

  class PostgresqlRangeTest < ActiveRecord::TestCase
    test "update_all with ranges" do
      PostgresqlRange.create!

      PostgresqlRange.update_all(int8_range: 1..100)

      assert_equal 1...101, PostgresqlRange.first.int8_range
    end

    test "ranges correctly escape input" do
      e = assert_raises(ActiveRecord::StatementInvalid) do
        range = "1,2]'; SELECT * FROM users; --".."a"
        PostgresqlRange.update_all(int8_range: range)
      end

      assert e.message.starts_with?("PG::InvalidTextRepresentation")
    end
  end
end
