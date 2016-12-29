require "cases/helper"
require "models/book"
require "support/schema_dumping_helper"

module ViewBehavior
  include SchemaDumpingHelper
  extend ActiveSupport::Concern

  included do
    fixtures :books
  end

  class Ebook < ActiveRecord::Base
    self.table_name = "ebooks'"
    self.primary_key = "id"
  end

  def setup
    super
    @connection = ActiveRecord::Base.connection
    create_view "ebooks'", <<-SQL
      SELECT id, name, status FROM books WHERE format = 'ebook'
    SQL
  end

  def teardown
    super
    drop_view "ebooks'"
  end

  def test_reading
    books = Ebook.all
    assert_equal [books(:rfr).id], books.map(&:id)
    assert_equal ["Ruby for Rails"], books.map(&:name)
  end

  def test_views
    assert_equal [Ebook.table_name], @connection.views
  end

  def test_view_exists
    view_name = Ebook.table_name
    assert @connection.view_exists?(view_name), "'#{view_name}' view should exist"
  end

  def test_table_exists
    view_name = Ebook.table_name
    # TODO: switch this assertion around once we changed #tables to not return views.
    ActiveSupport::Deprecation.silence { assert @connection.table_exists?(view_name), "'#{view_name}' table should exist" }
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
    assert_equal({ "id" => 2, "name" => "Ruby for Rails", "status" => 0 },
                 Ebook.first.attributes)
  end

  def test_does_not_assume_id_column_as_primary_key
    model = Class.new(ActiveRecord::Base) do
      self.table_name = "ebooks'"
    end
    assert_nil model.primary_key
  end

  def test_does_not_dump_view_as_table
    schema = dump_table_schema "ebooks'"
    assert_no_match %r{create_table "ebooks'"}, schema
  end

  private
    def quote_table_name(name)
      @connection.quote_table_name(name)
    end
end

if ActiveRecord::Base.connection.supports_views?
  class ViewWithPrimaryKeyTest < ActiveRecord::TestCase
    include ViewBehavior

    private
      def create_view(name, query)
        @connection.execute "CREATE VIEW #{quote_table_name(name)} AS #{query}"
      end

      def drop_view(name)
        @connection.execute "DROP VIEW #{quote_table_name(name)}" if @connection.view_exists? name
      end
  end

  class ViewWithoutPrimaryKeyTest < ActiveRecord::TestCase
    include SchemaDumpingHelper
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
      @connection.execute "DROP VIEW paperbacks" if @connection.view_exists? "paperbacks"
    end

    def test_reading
      books = Paperback.all
      assert_equal ["Agile Web Development with Rails"], books.map(&:name)
    end

    def test_views
      assert_equal [Paperback.table_name], @connection.views
    end

    def test_view_exists
      view_name = Paperback.table_name
      assert @connection.view_exists?(view_name), "'#{view_name}' view should exist"
    end

    def test_table_exists
      view_name = Paperback.table_name
      # TODO: switch this assertion around once we changed #tables to not return views.
      ActiveSupport::Deprecation.silence { assert @connection.table_exists?(view_name), "'#{view_name}' table should exist" }
    end

    def test_column_definitions
      assert_equal([["name", :string],
                    ["status", :integer]], Paperback.columns.map { |c| [c.name, c.type] })
    end

    def test_attributes
      assert_equal({ "name" => "Agile Web Development with Rails", "status" => 2 },
                   Paperback.first.attributes)
    end

    def test_does_not_have_a_primary_key
      assert_nil Paperback.primary_key
    end

    def test_does_not_dump_view_as_table
      schema = dump_table_schema "paperbacks"
      assert_no_match %r{create_table "paperbacks"}, schema
    end
  end

  # sqlite dose not support CREATE, INSERT, and DELETE for VIEW
  if current_adapter?(:Mysql2Adapter, :PostgreSQLAdapter)
    class UpdateableViewTest < ActiveRecord::TestCase
      self.use_transactional_tests = false
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
        @connection.execute "DROP VIEW printed_books" if @connection.view_exists? "printed_books"
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
  end # end fo `if current_adapter?(:Mysql2Adapter, :PostgreSQLAdapter)`
end # end fo `if ActiveRecord::Base.connection.supports_views?`

if ActiveRecord::Base.connection.respond_to?(:supports_materialized_views?) &&
    ActiveRecord::Base.connection.supports_materialized_views?
  class MaterializedViewTest < ActiveRecord::PostgreSQLTestCase
    include ViewBehavior

    private
      def create_view(name, query)
        @connection.execute "CREATE MATERIALIZED VIEW #{quote_table_name(name)} AS #{query}"
      end

      def drop_view(name)
        @connection.execute "DROP MATERIALIZED VIEW #{quote_table_name(name)}" if @connection.view_exists? name
      end
  end
end
