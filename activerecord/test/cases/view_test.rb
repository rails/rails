require "cases/helper"
require "models/book"

module ViewBehavior
  extend ActiveSupport::Concern

  included do
    fixtures :books
  end

  class Ebook < ActiveRecord::Base
    self.primary_key = "id"
  end

  def setup
    super
    @connection = ActiveRecord::Base.connection
    create_view "ebooks", <<-SQL
      SELECT id, name, status FROM books WHERE format = 'ebook'
    SQL
  end

  def teardown
    super
    drop_view "ebooks"
  end

  def test_reading
    books = Ebook.all
    assert_equal [books(:rfr).id], books.map(&:id)
    assert_equal ["Ruby for Rails"], books.map(&:name)
  end

  def test_table_exists
    view_name = Ebook.table_name
    # TODO: switch this assertion around once we changed #tables to not return views.
    assert @connection.table_exists?(view_name), "'#{view_name}' table should exist"
  end

  def test_views_ara_valid_data_sources
    view_name = Ebook.table_name
    assert @connection.data_source_exists?(view_name), "'#{view_name}' should be a data source"
  end

  def test_column_definitions
    assert_equal([["id", :integer],
                  ["name", :string],
                  ["status", :integer]], Ebook.columns.map { |c| [c.name, c.type] })
  end

  def test_attributes
    assert_equal({"id" => 2, "name" => "Ruby for Rails", "status" => 0},
                 Ebook.first.attributes)
  end

  def test_does_not_assume_id_column_as_primary_key
    model = Class.new(ActiveRecord::Base) do
      self.table_name = "ebooks"
    end
    assert_nil model.primary_key
  end
end

if ActiveRecord::Base.connection.supports_views?
class ViewWithPrimaryKeyTest < ActiveRecord::TestCase
  include ViewBehavior

  private
  def create_view(name, query)
    @connection.execute "CREATE VIEW #{name} AS #{query}"
  end

  def drop_view(name)
    @connection.execute "DROP VIEW #{name}" if @connection.table_exists? name
  end
end

class ViewWithoutPrimaryKeyTest < ActiveRecord::TestCase
  fixtures :books

  class Paperback < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.execute <<-SQL
      CREATE VIEW paperbacks
        AS SELECT name, status FROM books WHERE format = 'paperback'
    SQL
  end

  teardown do
    @connection.execute "DROP VIEW paperbacks" if @connection.table_exists? "paperbacks"
  end

  def test_reading
    books = Paperback.all
    assert_equal ["Agile Web Development with Rails"], books.map(&:name)
  end

  def test_table_exists
    view_name = Paperback.table_name
    assert @connection.table_exists?(view_name), "'#{view_name}' table should exist"
  end

  def test_column_definitions
    assert_equal([["name", :string],
                  ["status", :integer]], Paperback.columns.map { |c| [c.name, c.type] })
  end

  def test_attributes
    assert_equal({"name" => "Agile Web Development with Rails", "status" => 0},
                 Paperback.first.attributes)
  end

  def test_does_not_have_a_primary_key
    assert_nil Paperback.primary_key
  end
end
end
