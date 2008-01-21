require "cases/helper"

class CopyTableTest < ActiveRecord::TestCase
  fixtures :companies, :comments

  def setup
    @connection = ActiveRecord::Base.connection
    class << @connection
      public :copy_table, :table_structure, :indexes
    end
  end

  def test_copy_table(from = 'companies', to = 'companies2', options = {})
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
    test_copy_table('companies', 'companies2',
        :rename => {'client_of' => 'fan_of'}) do |from, to, options|
      expected = column_values(from, 'client_of')
      assert expected.any?, 'only nils in resultset; real values are needed'
      assert_equal expected, column_values(to, 'fan_of')
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
