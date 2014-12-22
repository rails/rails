require 'cases/helper'

if ActiveRecord::Base.connection.supports_foreign_keys?
module ActiveRecord
  class Migration
    class ReferencesForeignKeyTest < ActiveRecord::TestCase
      setup do
        @connection = ActiveRecord::Base.connection
        @connection.create_table(:testing_parents, force: true)
      end

      teardown do
        @connection.execute("drop table if exists testings")
        @connection.execute("drop table if exists testing_parents")
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
    end
  end
end
end
