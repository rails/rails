require "cases/helper"

class PostgresqlHstoreTest < ActiveRecord::TestCase
  class Hstore < ActiveRecord::Base
    self.table_name = 'hstores'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table('hstores') do |t|
      t.hstore 'tags'
    end
  end

  def teardown
    @connection.execute 'drop table if exists hstores'
  end

  def test_column
    column = Hstore.columns.find { |c| c.name == 'tags' }
    assert column
    assert_equal :hstore, column.type
  end
end
