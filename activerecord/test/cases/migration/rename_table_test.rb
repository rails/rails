# frozen_string_literal: true

require "cases/migration/helper"

module ActiveRecord
  class Migration
    class RenameTableTest < ActiveRecord::TestCase
      include ActiveRecord::Migration::TestHelper

      self.use_transactional_tests = false

      def setup
        super
        add_column "test_models", :url, :string
        remove_column "test_models", :created_at
        remove_column "test_models", :updated_at
      end

      def teardown
        rename_table :octopi, :test_models if connection.table_exists? :octopi
        super
      end

      unless current_adapter?(:OracleAdapter)
        def test_rename_table_should_work_with_reserved_words
          renamed = false

          add_column :test_models, :url, :string
          connection.rename_table :references, :old_references
          connection.rename_table :test_models, :references

          renamed = true

          # Using explicit id in insert for compatibility across all databases
          connection.execute "INSERT INTO 'references' (url, created_at, updated_at) VALUES ('http://rubyonrails.com', 0, 0)"
          assert_equal "http://rubyonrails.com", connection.select_value("SELECT url FROM 'references' WHERE id=1")
        ensure
          return unless renamed
          connection.rename_table :references, :test_models
          connection.rename_table :old_references, :references
        end
      end

      def test_rename_table
        rename_table :test_models, :octopi

        connection.execute "INSERT INTO octopi (#{connection.quote_column_name('id')}, #{connection.quote_column_name('url')}) VALUES (1, 'http://www.foreverflying.com/octopus-black7.jpg')"

        assert_equal "http://www.foreverflying.com/octopus-black7.jpg", connection.select_value("SELECT url FROM octopi WHERE id=1")
      end

      def test_rename_table_with_an_index
        add_index :test_models, :url

        rename_table :test_models, :octopi

        connection.execute "INSERT INTO octopi (#{connection.quote_column_name('id')}, #{connection.quote_column_name('url')}) VALUES (1, 'http://www.foreverflying.com/octopus-black7.jpg')"

        assert_equal "http://www.foreverflying.com/octopus-black7.jpg", connection.select_value("SELECT url FROM octopi WHERE id=1")
        index = connection.indexes(:octopi).first
        assert_includes index.columns, "url"
        assert_equal "index_octopi_on_url", index.name
      end

      def test_rename_table_does_not_rename_custom_named_index
        add_index :test_models, :url, name: "special_url_idx"

        rename_table :test_models, :octopi

        assert_equal ["special_url_idx"], connection.indexes(:octopi).map(&:name)
      end

      if current_adapter?(:PostgreSQLAdapter)
        def test_rename_table_for_postgresql_should_also_rename_default_sequence
          rename_table :test_models, :octopi

          pk, seq = connection.pk_and_sequence_for("octopi")

          assert_equal ConnectionAdapters::PostgreSQL::Name.new("public", "octopi_#{pk}_seq"), seq
        end

        def test_renaming_table_renames_primary_key
          connection.create_table :cats, id: :uuid, default: "uuid_generate_v4()"
          rename_table :cats, :felines

          assert connection.table_exists? :felines
          assert_not connection.table_exists? :cats

          primary_key_name = connection.select_values(<<~SQL, "SCHEMA")[0]
            SELECT c.relname
              FROM pg_class c
              JOIN pg_index i
                ON c.oid = i.indexrelid
             WHERE i.indisprimary
               AND i.indrelid = 'felines'::regclass
          SQL

          assert_equal "felines_pkey", primary_key_name
        ensure
          connection.drop_table :cats, if_exists: true
          connection.drop_table :felines, if_exists: true
        end

        def test_renaming_table_doesnt_attempt_to_rename_non_existent_sequences
          connection.create_table :cats, id: :uuid, default: "uuid_generate_v4()"
          assert_nothing_raised { rename_table :cats, :felines }
          assert connection.table_exists? :felines
          assert_not connection.table_exists? :cats
        ensure
          connection.drop_table :cats, if_exists: true
          connection.drop_table :felines, if_exists: true
        end
      end
    end
  end
end
