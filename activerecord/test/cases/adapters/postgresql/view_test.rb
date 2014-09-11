require "cases/helper"
require "cases/view_test"

class UpdateableViewTest < ActiveRecord::TestCase
  fixtures :books

  class PrintedBook < ActiveRecord::Base
    self.primary_key = "id"
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.execute <<-SQL
      CREATE VIEW printed_books
        AS SELECT id, name, status, format FROM books WHERE format = 'paperback'
    SQL
  end

  teardown do
    @connection.execute "DROP VIEW printed_books" if @connection.table_exists? "printed_books"
  end

  def test_update_record
    book = PrintedBook.first
    book.name = "AWDwR"
    book.save!
    book.reload
    assert_equal "AWDwR", book.name
  end

  def test_insert_record
    PrintedBook.create! name: "Rails in Action", status: 0, format: "paperback"

    new_book = PrintedBook.last
    assert_equal "Rails in Action", new_book.name
  end

  def test_update_record_to_fail_view_conditions
    book = PrintedBook.first
    book.format = "ebook"
    book.save!

    assert_raises ActiveRecord::RecordNotFound do
      book.reload
    end
  end
end

if ActiveRecord::Base.connection.supports_materialized_views?
class MaterializedViewTest < ActiveRecord::TestCase
  include ViewBehavior

  private
  def create_view(name, query)
    @connection.execute "CREATE MATERIALIZED VIEW #{name} AS #{query}"
  end

  def drop_view(name)
    @connection.execute "DROP MATERIALIZED VIEW #{name}" if @connection.table_exists? name

  end
end
end
