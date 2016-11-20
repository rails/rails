require "cases/helper"

if ActiveRecord::Base.connection.supports_foreign_keys?
  module ActiveRecord
    class Migration
      class ReferencesForeignKeyTest < ActiveRecord::TestCase
        setup do
          @connection = ActiveRecord::Base.connection
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
          assert_queries(1) do
            @connection.create_table :testings do |t|
              t.references :testing_parent, foreign_key: true, index: false
            end
          end
        end

        test "options hash can be passed" do
          @connection.change_table :testing_parents do |t|
            t.integer :other_id
            t.index :other_id, unique: true
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
            t.integer :other_id
            t.index :other_id, unique: true
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

        test "foreign key methods respect pluralize_table_names" do
          begin
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
            t.integer :col_1
            t.integer :col_2

            t.foreign_key :testing_parents, column: :col_1
            t.foreign_key :testing_parents, column: :col_2
          end

          fks = @connection.foreign_keys("testings")

          fk_definitions = fks.map { |fk| [fk.from_table, fk.to_table, fk.column] }
          assert_equal([["testings", "testing_parents", "col_1"],
                        ["testings", "testing_parents", "col_2"]], fk_definitions)
        end
      end
    end
  end
else
  class ReferencesWithoutForeignKeySupportTest < ActiveRecord::TestCase
    setup do
      @connection = ActiveRecord::Base.connection
      @connection.create_table(:testing_parents, force: true)
    end

    teardown do
      @connection.drop_table("testings", if_exists: true)
      @connection.drop_table("testing_parents", if_exists: true)
    end

    test "ignores foreign keys defined with the table" do
      @connection.create_table :testings do |t|
        t.references :testing_parent, foreign_key: true
      end

      assert_includes @connection.data_sources, "testings"
    end
  end
end
