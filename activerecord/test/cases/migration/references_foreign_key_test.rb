# frozen_string_literal: true

require "cases/helper"

if ActiveRecord::Base.lease_connection.supports_foreign_keys?
  module ActiveRecord
    class Migration
      class ReferencesForeignKeyInCreateTest < ActiveRecord::TestCase
        setup do
          @connection = ActiveRecord::Base.lease_connection
          @connection.create_table(:testing_parents, force: true)
        end

        teardown do
          @connection.drop_table "testings", if_exists: true
          @connection.drop_table "testing_parents", if_exists: true
        end

        test "foreign keys can be created with the table" do
          @connection.create_table :testings do |t|
            t.references :testing_parent, foreign_key: true
          end

          fk = @connection.foreign_keys("testings").first
          assert_equal "testings", fk.from_table
          assert_equal "testing_parents", fk.to_table
        end

        test "no foreign key is created by default" do
          @connection.create_table :testings do |t|
            t.references :testing_parent
          end

          assert_equal [], @connection.foreign_keys("testings")
        end

        test "foreign keys can be created in one query when index is not added" do
          assert_queries_count(1) do
            @connection.create_table :testings do |t|
              t.references :testing_parent, foreign_key: true, index: false
            end
          end
        end

        test "options hash can be passed" do
          @connection.change_table :testing_parents do |t|
            t.references :other, index: { unique: true }
          end
          @connection.create_table :testings do |t|
            t.references :testing_parent, foreign_key: { primary_key: :other_id }
          end

          fk = @connection.foreign_keys("testings").find { |k| k.to_table == "testing_parents" }
          assert_equal "other_id", fk.primary_key
        end

        test "to_table option can be passed" do
          @connection.create_table :testings do |t|
            t.references :parent, foreign_key: { to_table: :testing_parents }
          end
          fks = @connection.foreign_keys("testings")
          assert_equal([["testings", "testing_parents", "parent_id"]],
                       fks.map { |fk| [fk.from_table, fk.to_table, fk.column] })
        end

        if ActiveRecord::Base.lease_connection.supports_deferrable_constraints?
          test "deferrable: false option can be passed" do
            @connection.create_table :testings do |t|
              t.references :testing_parent, foreign_key: { deferrable: false }
            end

            fks = @connection.foreign_keys("testings")
            assert_equal([["testings", "testing_parents", "testing_parent_id", false]],
                         fks.map { |fk| [fk.from_table, fk.to_table, fk.column, fk.deferrable] })
          end

          test "deferrable: :immediate option can be passed" do
            @connection.create_table :testings do |t|
              t.references :testing_parent, foreign_key: { deferrable: :immediate }
            end

            fks = @connection.foreign_keys("testings")
            assert_equal([["testings", "testing_parents", "testing_parent_id", :immediate]],
                         fks.map { |fk| [fk.from_table, fk.to_table, fk.column, fk.deferrable] })
          end

          test "deferrable: :deferred option can be passed" do
            @connection.create_table :testings do |t|
              t.references :testing_parent, foreign_key: { deferrable: :deferred }
            end

            fks = @connection.foreign_keys("testings")
            assert_equal([["testings", "testing_parents", "testing_parent_id", :deferred]],
                         fks.map { |fk| [fk.from_table, fk.to_table, fk.column, fk.deferrable] })
          end

          test "deferrable and on_(delete|update) option can be passed" do
            @connection.create_table :testings do |t|
              t.references :testing_parent, foreign_key: { on_update: :cascade, on_delete: :cascade, deferrable: :immediate }
            end

            fks = @connection.foreign_keys("testings")
            assert_equal([["testings", "testing_parents", "testing_parent_id", :cascade, :cascade, :immediate]],
                         fks.map { |fk| [fk.from_table, fk.to_table, fk.column, fk.on_delete, fk.on_update, fk.deferrable] })
          end
        end
      end
    end
  end

  module ActiveRecord
    class Migration
      class ReferencesForeignKeyTest < ActiveRecord::TestCase
        setup do
          @connection = ActiveRecord::Base.lease_connection
          @connection.create_table(:testing_parents, force: true)
        end

        teardown do
          @connection.drop_table "testings", if_exists: true
          @connection.drop_table "testing_parents", if_exists: true
        end

        test "foreign keys cannot be added to polymorphic relations when creating the table" do
          @connection.create_table :testings do |t|
            assert_raises(ArgumentError) do
              t.references :testing_parent, polymorphic: true, foreign_key: true
            end
          end
        end

        test "foreign keys can be created while changing the table" do
          @connection.create_table :testings
          @connection.change_table :testings do |t|
            t.references :testing_parent, foreign_key: true
          end

          fk = @connection.foreign_keys("testings").first
          assert_equal "testings", fk.from_table
          assert_equal "testing_parents", fk.to_table
        end

        test "foreign keys are not added by default when changing the table" do
          @connection.create_table :testings
          @connection.change_table :testings do |t|
            t.references :testing_parent
          end

          assert_equal [], @connection.foreign_keys("testings")
        end

        test "foreign keys accept options when changing the table" do
          @connection.change_table :testing_parents do |t|
            t.references :other, index: { unique: true }
          end
          @connection.create_table :testings
          @connection.change_table :testings do |t|
            t.references :testing_parent, foreign_key: { primary_key: :other_id }
          end

          fk = @connection.foreign_keys("testings").find { |k| k.to_table == "testing_parents" }
          assert_equal "other_id", fk.primary_key
        end

        test "foreign keys cannot be added to polymorphic relations when changing the table" do
          @connection.create_table :testings
          @connection.change_table :testings do |t|
            assert_raises(ArgumentError) do
              t.references :testing_parent, polymorphic: true, foreign_key: true
            end
          end
        end

        test "foreign key column can be removed" do
          @connection.create_table :testings do |t|
            t.references :testing_parent, index: true, foreign_key: true
          end

          assert_difference "@connection.foreign_keys('testings').size", -1 do
            @connection.remove_reference :testings, :testing_parent, foreign_key: true
          end
        end

        test "removing column removes foreign key" do
          @connection.create_table :testings do |t|
            t.references :testing_parent, index: true, foreign_key: true
          end

          assert_difference "@connection.foreign_keys('testings').size", -1 do
            @connection.remove_column :testings, :testing_parent_id
          end
        end

        test "foreign key methods respect pluralize_table_names" do
          original_pluralize_table_names = ActiveRecord::Base.pluralize_table_names
          ActiveRecord::Base.pluralize_table_names = false
          @connection.create_table :testing
          @connection.change_table :testing_parents do |t|
            t.references :testing, foreign_key: true
          end

          fk = @connection.foreign_keys("testing_parents").first
          assert_equal "testing_parents", fk.from_table
          assert_equal "testing", fk.to_table

          assert_difference "@connection.foreign_keys('testing_parents').size", -1 do
            @connection.remove_reference :testing_parents, :testing, foreign_key: true
          end
        ensure
          ActiveRecord::Base.pluralize_table_names = original_pluralize_table_names
          @connection.drop_table "testing", if_exists: true
        end

        test "remove_reference responds to if_exists option" do
          @connection.create_table :testings

          assert_nothing_raised do
            @connection.remove_reference :testings, :nonexistent, foreign_key: true, if_exists: true
          end
        end

        test "add_reference responds to if_not_exists option" do
          @connection.create_table :testings do |t|
            t.references :testing, foreign_key: true
          end

          assert_nothing_raised do
            @connection.add_reference :testings, :testing, foreign_key: true, if_not_exists: true
          end
        end

        class CreateDogsMigration < ActiveRecord::Migration::Current
          def change
            create_table :dog_owners

            create_table :dogs do |t|
              t.references :dog_owner, foreign_key: true
            end
          end
        end

        def test_references_foreign_key_with_prefix
          ActiveRecord::Base.table_name_prefix = "p_"
          migration = CreateDogsMigration.new
          silence_stream($stdout) { migration.migrate(:up) }
          assert_equal 1, @connection.foreign_keys("p_dogs").size
        ensure
          silence_stream($stdout) { migration.migrate(:down) }
          ActiveRecord::Base.table_name_prefix = nil
        end

        def test_references_foreign_key_with_suffix
          ActiveRecord::Base.table_name_suffix = "_s"
          migration = CreateDogsMigration.new
          silence_stream($stdout) { migration.migrate(:up) }
          assert_equal 1, @connection.foreign_keys("dogs_s").size
        ensure
          silence_stream($stdout) { migration.migrate(:down) }
          ActiveRecord::Base.table_name_suffix = nil
        end

        test "multiple foreign keys can be added to the same table" do
          @connection.create_table :testings do |t|
            t.references :parent1, foreign_key: { to_table: :testing_parents }
            t.references :parent2, foreign_key: { to_table: :testing_parents }
            t.references :self_join, foreign_key: { to_table: :testings }
          end

          fks = @connection.foreign_keys("testings").sort_by(&:column)

          fk_definitions = fks.map { |fk| [fk.from_table, fk.to_table, fk.column] }
          assert_equal([["testings", "testing_parents", "parent1_id"],
                        ["testings", "testing_parents", "parent2_id"],
                        ["testings", "testings", "self_join_id"]], fk_definitions)
        end

        test "multiple foreign keys can be removed to the selected one" do
          @connection.create_table :testings do |t|
            t.references :parent1, foreign_key: { to_table: :testing_parents }
            t.references :parent2, foreign_key: { to_table: :testing_parents }
          end

          assert_difference "@connection.foreign_keys('testings').size", -1 do
            @connection.remove_reference :testings, :parent1, foreign_key: { to_table: :testing_parents }
          end

          fks = @connection.foreign_keys("testings").sort_by(&:column)

          fk_definitions = fks.map { |fk| [fk.from_table, fk.to_table, fk.column] }
          assert_equal([["testings", "testing_parents", "parent2_id"]], fk_definitions)
        end
      end
    end
  end
end
