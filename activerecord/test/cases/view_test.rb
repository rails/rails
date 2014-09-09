require "cases/helper"
require "models/book"

if ActiveRecord::Base.connection.supports_views?
class ViewWithPrimaryKeyTest < ActiveRecord::TestCase
  fixtures :books

  class Ebook < ActiveRecord::Base
    self.primary_key = "id"
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.execute <<-SQL
      CREATE VIEW ebooks
        AS SELECT id, name, status FROM books WHERE format = 'ebook'
    SQL
  end

  teardown do
    @connection.execute "DROP VIEW IF EXISTS ebooks"
  end

  def test_reading
    books = Ebook.all
    assert_equal [books(:rfr).id], books.map(&:id)
    assert_equal ["Ruby for Rails"], books.map(&:name)
  end

  def test_table_exists
    view_name = Ebook.table_name
    assert @connection.table_exists?(view_name), "'#{view_name}' table should exist"
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
    @connection.execute "DROP VIEW IF EXISTS paperbacks"
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
end
end
