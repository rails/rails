require "cases/helper"

class CopyTableTest < ActiveRecord::TestCase
  fixtures :customers, :companies, :comments

  def setup
    @connection = ActiveRecord::Base.connection
    class << @connection
      public :copy_table, :table_structure, :indexes
    end
  end

  def test_copy_table(from = 'customers', to = 'customers2', options = {})
    assert_nothing_raised {copy_table(from, to, options)}
    assert_equal row_count(from), row_count(to)

    if block_given?
      yield from, to, options
    else
      assert_equal column_names(from), column_names(to)
    end

    @connection.drop_table(to) rescue nil
  end

  def test_copy_table_renaming_column
    test_copy_table('customers', 'customers2',
        :rename => {'name' => 'person_name'}) do |from, to, options|
      expected = column_values(from, 'name')
      assert_equal expected, column_values(to, 'person_name')
      assert expected.any?, "No values in table: #{expected.inspect}"
    end
  end

  def test_copy_table_with_index
    test_copy_table('comments', 'comments_with_index') do
      @connection.add_index('comments_with_index', ['post_id', 'type'])
      test_copy_table('comments_with_index', 'comments_with_index2') do
        assert_equal table_indexes_without_name('comments_with_index'),
                     table_indexes_without_name('comments_with_index2')
      end
    end
  end

  def test_copy_table_without_primary_key
    test_copy_table('developers_projects', 'programmers_projects')
  end

  def test_copy_table_with_id_col_that_is_not_primary_key
    test_copy_table('goofy_string_id', 'goofy_string_id2') do |from, to, options|
      original_id = @connection.columns('goofy_string_id').detect{|col| col.name == 'id' }
      copied_id = @connection.columns('goofy_string_id2').detect{|col| col.name == 'id' }
      assert_equal original_id.type, copied_id.type
      assert_equal original_id.sql_type, copied_id.sql_type
      assert_equal original_id.limit, copied_id.limit
      assert_equal original_id.primary, copied_id.primary
    end
  end

  def test_copy_table_with_unconventional_primary_key
    test_copy_table('owners', 'owners_unconventional') do |from, to, options|
      original_pk = @connection.primary_key('owners')
      copied_pk = @connection.primary_key('owners_unconventional')
      assert_equal original_pk, copied_pk
    end
  end

protected
  def copy_table(from, to, options = {})
    @connection.copy_table(from, to, {:temporary => true}.merge(options))
  end

  def column_names(table)
    @connection.table_structure(table).map {|column| column['name']}
  end

  def column_values(table, column)
    @connection.select_all("SELECT #{column} FROM #{table} ORDER BY id").map {|row| row[column]}
  end

  def table_indexes_without_name(table)
    @connection.indexes('comments_with_index').delete(:name)
  end

  def row_count(table)
    @connection.select_one("SELECT COUNT(*) AS count FROM #{table}")['count']
  end
end
