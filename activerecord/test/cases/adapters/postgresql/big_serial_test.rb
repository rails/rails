require "cases/helper"
require "support/schema_dumping_helper"

class PostgresqlBigSerialTest < ActiveRecord::TestCase
  include SchemaDumpingHelper

  class PostgresqlBigSerial < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:postgresql_big_serials, force: true, id: :bigserial) do |t|
    end
  end

  teardown do
    if @connection
      @connection.execute('DROP TABLE IF EXISTS postgresql_big_serials')
    end
  end

  test "bigserial columns have a limit of 8" do
    assert_equal 8, PostgresqlBigSerial.columns_hash['id'].limit
  end

  test "bigserial primary keys are dumped correctly" do
    output = dump_table_schema("postgresql_big_serials")
    assert_match %r(create_table "postgresql_big_serials",.*\sid: :bigserial), output
    assert_no_match %r(create_table "postgresql_big_serials",.*default), output
  end
end
