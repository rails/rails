# frozen_string_literal: true

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
    @connection = ActiveRecord::Base.lease_connection
    create_view "ebooks'", <<~SQL
      SELECT id, name, cover, status FROM books WHERE format = 'ebook'
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
    assert_not @connection.table_exists?(view_name), "'#{view_name}' table should not exist"
  end

  def test_views_ara_valid_data_sources
    view_name = Ebook.table_name
    assert @connection.data_source_exists?(view_name), "'#{view_name}' should be a data source"
  end

  def test_column_definitions
    assert_equal([["id", :integer],
                  ["name", :string],
                  ["cover", :string],
                  ["status", :integer]], Ebook.columns.map { |c| [c.name, c.type] })
  end

  def test_attributes
    assert_equal({ "id" => 2, "name" => "Ruby for Rails", "cover" => "hard", "status" => 0 },
                 Ebook.first.attributes)
  end

  def test_does_not_assume_id_column_as_primary_key
    view_name = "ebooks_computed_id"
    create_view view_name, "SELECT 0 AS id, name FROM books"

    model = Class.new(ActiveRecord::Base) do
      self.table_name = "ebooks_computed_id"
    end

    assert_nil model.primary_key
  ensure
    drop_view view_name
  end

  def test_does_not_dump_view_as_table
    schema = dump_table_schema "ebooks'"
    assert_no_match %r{create_table "ebooks'"}, schema
  end
end

if ActiveRecord::Base.lease_connection.supports_views?
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

    self.use_transactional_tests = false
    fixtures :books

    class Paperback < ActiveRecord::Base; end

    setup do
      @connection = ActiveRecord::Base.lease_connection
      @connection.execute <<~SQL
        CREATE VIEW paperbacks
          AS SELECT name, status FROM books WHERE format = 'paperback'
      SQL
    end

    teardown do
      @connection.execute "DROP VIEW paperbacks" if @connection&.view_exists? "paperbacks"
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
      assert_not @connection.table_exists?(view_name), "'#{view_name}' table should not exist"
    end

    def test_column_definitions
      assert_equal([["name", :string],
                    ["status", :integer]], Paperback.columns.map { |c| [c.name, c.type] })
    end

    def test_attributes
      assert_equal({ "name" => "Agile Web Development with Rails", "status" => 2 },
                   Paperback.take.attributes)
    end

    def test_does_not_have_a_primary_key
      assert_nil Paperback.primary_key
    end

    def test_does_not_dump_view_as_table
      schema = dump_table_schema "paperbacks"
      assert_no_match %r{create_table "paperbacks"}, schema
    end
  end

  class UpdateableViewTest < ActiveRecord::TestCase
    # SQLite does not support CREATE, INSERT, and DELETE for VIEW
    if current_adapter?(:Mysql2Adapter, :TrilogyAdapter, :PostgreSQLAdapter)
      self.use_transactional_tests = false
      fixtures :books

      class PrintedBook < ActiveRecord::Base
        self.primary_key = "id"
      end

      setup do
        @connection = ActiveRecord::Base.lease_connection
        @connection.execute <<~SQL
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

      def test_insert_record_populates_primary_key
        book = PrintedBook.create! name: "Rails in Action", status: 0, format: "paperback"
        assert_not_nil book.id
        assert book.id > 0
      end if current_adapter?(:PostgreSQLAdapter, :SQLite3Adapter) && supports_insert_returning?

      def test_update_record_to_fail_view_conditions
        book = PrintedBook.first
        book.format = "ebook"
        book.save!

        assert_raises ActiveRecord::RecordNotFound do
          book.reload
        end
      end
    end # end of `if current_adapter?(:Mysql2Adapter, :TrilogyAdapter, :PostgreSQLAdapter)`
  end

  class PostgreSQLViewPrimaryKeyInferenceTest < ActiveRecord::TestCase
    if current_adapter?(:PostgreSQLAdapter)
      self.use_transactional_tests = false
      fixtures :books

      setup do
        @connection = ActiveRecord::Base.lease_connection
      end

      teardown do
        @connection.execute "DROP VIEW IF EXISTS simple_books_view"
        @connection.execute "DROP VIEW IF EXISTS no_pk_books_view"
        @connection.execute "DROP VIEW IF EXISTS computed_id_books_view"
        @connection.execute "DROP VIEW IF EXISTS cpk_posts_view"
        @connection.execute "DROP VIEW IF EXISTS partial_cpk_posts_view"
      end

      def test_infers_primary_key_for_simple_view
        @connection.execute <<~SQL
          CREATE VIEW simple_books_view AS SELECT * FROM books
        SQL

        model = Class.new(ActiveRecord::Base) do
          self.table_name = "simple_books_view"
        end

        assert_equal "id", model.primary_key
      end

      def test_no_primary_key_when_pk_column_missing_from_view
        @connection.execute <<~SQL
          CREATE VIEW no_pk_books_view AS SELECT name, status FROM books
        SQL

        model = Class.new(ActiveRecord::Base) do
          self.table_name = "no_pk_books_view"
        end

        assert_nil model.primary_key
      end

      def test_no_primary_key_when_pk_column_is_computed
        @connection.execute <<~SQL
          CREATE VIEW computed_id_books_view AS SELECT 0 AS id, name FROM books
        SQL

        model = Class.new(ActiveRecord::Base) do
          self.table_name = "computed_id_books_view"
        end

        assert_nil model.primary_key
      end

      def test_infers_composite_primary_key_from_view
        @connection.execute <<~SQL
          CREATE VIEW cpk_posts_view AS SELECT * FROM cpk_posts
        SQL

        model = Class.new(ActiveRecord::Base) do
          self.table_name = "cpk_posts_view"
        end

        assert_equal ["title", "author"], model.primary_key
      end

      def test_no_primary_key_when_composite_pk_column_missing_from_view
        @connection.execute <<~SQL
          CREATE VIEW partial_cpk_posts_view AS SELECT title FROM cpk_posts
        SQL

        model = Class.new(ActiveRecord::Base) do
          self.table_name = "partial_cpk_posts_view"
        end

        assert_nil model.primary_key
      end
    end
  end
end # end of `if ActiveRecord::Base.lease_connection.supports_views?`

if ActiveRecord::Base.lease_connection.supports_materialized_views?
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
