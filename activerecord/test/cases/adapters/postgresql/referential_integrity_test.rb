require 'cases/helper'

class PostgreSQLReferentialIntegrityTest < ActiveRecord::TestCase
  class AFakeAdapter
    include ActiveRecord::ConnectionAdapters::PostgreSQL::ReferentialIntegrity

    def tables
      ['a_table']
    end

    def quote_table_name(name)
      "\"#{name}\""
    end

    def execute(sql)
      raise 'Forcing a exception' if sql.match(/DISABLE TRIGGER ALL/)
    end
  end

  def test_should_reraise_invalid_foreign_key_exception_and_show_warning
    warning = capture(:stderr) do
      assert_raises(ActiveRecord::InvalidForeignKey) do
        AFakeAdapter.new.disable_referential_integrity do
          raise ActiveRecord::InvalidForeignKey, 'Should be re-raised'
        end
      end
    end
    assert_match (/WARNING: Rails can't disable referential integrity/), warning
  end
end
