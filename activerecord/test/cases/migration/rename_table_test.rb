require "cases/migration/helper"

module ActiveRecord
  class Migration
    class RenameTableTest < ActiveRecord::TestCase
      include ActiveRecord::Migration::TestHelper

      self.use_transactional_fixtures = false

      def setup
        super
        add_column 'test_models', :url, :string
        remove_column 'test_models', :created_at
        remove_column 'test_models', :updated_at
      end

      def test_rename_table_for_sqlite_should_work_with_reserved_words
        renamed = false

        skip "not supported" unless current_adapter?(:SQLite3Adapter)

        add_column :test_models, :url, :string
        connection.rename_table :references, :old_references
        connection.rename_table :test_models, :references

        renamed = true

        # Using explicit id in insert for compatibility across all databases
        con = connection
        con.execute "INSERT INTO 'references' (url, created_at, updated_at) VALUES ('http://rubyonrails.com', 0, 0)"
        assert_equal 'http://rubyonrails.com', connection.select_value("SELECT url FROM 'references' WHERE id=1")
      ensure
        return unless renamed
        connection.rename_table :references, :test_models
        connection.rename_table :old_references, :references
      end

      def test_rename_table
        rename_table :test_models, :octopi

        # Using explicit id in insert for compatibility across all databases
        con = connection
        con.enable_identity_insert("octopi", true) if current_adapter?(:SybaseAdapter)

        con.execute "INSERT INTO octopi (#{con.quote_column_name('id')}, #{con.quote_column_name('url')}) VALUES (1, 'http://www.foreverflying.com/octopus-black7.jpg')"

        con.enable_identity_insert("octopi", false) if current_adapter?(:SybaseAdapter)

        assert_equal 'http://www.foreverflying.com/octopus-black7.jpg', connection.select_value("SELECT url FROM octopi WHERE id=1")

        rename_table :octopi, :test_models
      end

      def test_rename_table_with_an_index
        add_index :test_models, :url

        rename_table :test_models, :octopi

        # Using explicit id in insert for compatibility across all databases
        con = ActiveRecord::Base.connection
        con.enable_identity_insert("octopi", true) if current_adapter?(:SybaseAdapter)
        con.execute "INSERT INTO octopi (#{con.quote_column_name('id')}, #{con.quote_column_name('url')}) VALUES (1, 'http://www.foreverflying.com/octopus-black7.jpg')"
        con.enable_identity_insert("octopi", false) if current_adapter?(:SybaseAdapter)

        assert_equal 'http://www.foreverflying.com/octopus-black7.jpg', connection.select_value("SELECT url FROM octopi WHERE id=1")
        assert connection.indexes(:octopi).first.columns.include?("url")

        rename_table :octopi, :test_models
      end
    end
  end
end
