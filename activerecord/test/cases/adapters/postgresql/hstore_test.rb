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

  def test_type_cast_hstore
    column = Hstore.columns.find { |c| c.name == 'tags' }
    assert column

    data = "\"1\"=>\"2\""
    hash = column.class.cast_hstore data
    assert_equal({'1' => '2'}, hash)
    assert_equal({'1' => '2'}, column.type_cast(data))
  end

  def test_select
    @connection.execute "insert into hstores (tags) VALUES ('1=>2')"
    x = Hstore.find :first
    assert_equal({'1' => '2'}, x.tags)
  end

  def test_select_multikey
    @connection.execute "insert into hstores (tags) VALUES ('1=>2,2=>3')"
    x = Hstore.find :first
    assert_equal({'1' => '2', '2' => '3'}, x.tags)
  end
end
