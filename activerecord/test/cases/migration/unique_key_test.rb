# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.connection.supports_unique_keys?
  module ActiveRecord
    class Migration
      class UniqueKeyTest < ActiveRecord::TestCase
        include SchemaDumpingHelper

        class Section < ActiveRecord::Base
        end

        setup do
          @connection = ActiveRecord::Base.connection
          @connection.create_table "sections", force: true do |t|
            t.integer "position", null: false
          end
        end

        teardown do
          @connection.drop_table "sections", if_exists: true
        end

        def test_unique_keys
          unique_keys = @connection.unique_keys("test_unique_keys")

          expected_constraints = [
            {
              name: "test_unique_keys_position_deferrable_false",
              deferrable: false,
              columns: ["position_1"]
            }, {
              name: "test_unique_keys_position_deferrable_immediate",
              deferrable: :immediate,
              columns: ["position_2"]
            }, {
              name: "test_unique_keys_position_deferrable_deferred",
              deferrable: :deferred,
              columns: ["position_3"]
            }
          ]

          assert_equal expected_constraints.size, unique_keys.size

          expected_constraints.each do |expected_constraint|
            constraint = unique_keys.find { |constraint| constraint.name == expected_constraint[:name] }
            assert_equal "test_unique_keys", constraint.table_name
            assert_equal expected_constraint[:name], constraint.name
            assert_equal expected_constraint[:columns], constraint.columns
            assert_equal expected_constraint[:deferrable], constraint.deferrable
          end
        end

        def test_unique_keys_scoped_to_schemas
          @connection.add_unique_key :sections, [:position]

          assert_no_changes -> { @connection.unique_keys("sections").size } do
            @connection.create_schema "test_schema"
            @connection.create_table "test_schema.sections" do |t|
              t.integer :position
            end
            @connection.add_unique_key "test_schema.sections", [:position]
          end
        ensure
          @connection.drop_schema "test_schema"
        end

        def test_add_unique_key_without_deferrable
          @connection.add_unique_key :sections, [:position]

          unique_keys = @connection.unique_keys("sections")
          assert_equal 1, unique_keys.size

          constraint = unique_keys.first
          assert_equal "sections", constraint.table_name
          assert_equal "uniq_rails_3d89d7e853", constraint.name
          assert_equal false, constraint.deferrable
        end

        def test_add_unique_key_with_deferrable_false
          @connection.add_unique_key :sections, [:position], deferrable: false

          unique_keys = @connection.unique_keys("sections")
          assert_equal 1, unique_keys.size

          constraint = unique_keys.first
          assert_equal "sections", constraint.table_name
          assert_equal "uniq_rails_3d89d7e853", constraint.name
          assert_equal false, constraint.deferrable
        end

        def test_add_unique_key_with_deferrable_immediate
          @connection.add_unique_key :sections, [:position], deferrable: :immediate

          unique_keys = @connection.unique_keys("sections")
          assert_equal 1, unique_keys.size

          constraint = unique_keys.first
          assert_equal "sections", constraint.table_name
          assert_equal "uniq_rails_3d89d7e853", constraint.name
          assert_equal :immediate, constraint.deferrable
        end

        def test_add_unique_key_with_deferrable_deferred
          @connection.add_unique_key :sections, [:position], deferrable: :deferred

          unique_keys = @connection.unique_keys("sections")
          assert_equal 1, unique_keys.size

          constraint = unique_keys.first
          assert_equal "sections", constraint.table_name
          assert_equal "uniq_rails_3d89d7e853", constraint.name
          assert_equal :deferred, constraint.deferrable
        end

        def test_add_unique_key_with_deferrable_invalid
          error = assert_raises(ArgumentError) do
            @connection.add_unique_key :sections, [:position], deferrable: true
          end

          assert_equal "deferrable must be `:immediate` or `:deferred`, got: `true`", error.message
        end

        def test_added_deferrable_initially_immediate_unique_key
          @connection.add_unique_key :sections, [:position], deferrable: :immediate, name: "unique_section_position"

          section = Section.create!(position: 1)

          assert_raises(ActiveRecord::StatementInvalid) do
            Section.transaction(requires_new: true) do
              Section.create!(position: 1)
              section.update!(position: 2)
            end
          end

          assert_nothing_raised do
            Section.transaction(requires_new: true) do
              Section.connection.exec_query("SET CONSTRAINTS unique_section_position DEFERRED")
              Section.create!(position: 1)
              section.update!(position: 2)

              # NOTE: Clear `SET CONSTRAINTS` statement at the end of transaction.
              raise ActiveRecord::Rollback
            end
          end
        end

        def test_add_unique_key_with_name_and_using_index
          @connection.add_index :sections, [:position], name: "unique_index", unique: true
          @connection.add_unique_key :sections, name: "unique_constraint", deferrable: :immediate, using_index: "unique_index"

          unique_keys = @connection.unique_keys("sections")
          assert_equal 1, unique_keys.size

          constraint = unique_keys.first
          assert_equal "sections", constraint.table_name
          assert_equal "unique_constraint", constraint.name
          assert_equal ["position"], constraint.columns
          assert_equal :immediate, constraint.deferrable
        end

        def test_add_unique_key_with_only_using_index
          @connection.add_index :sections, [:position], name: "unique_index", unique: true
          @connection.add_unique_key :sections, using_index: "unique_index"

          unique_keys = @connection.unique_keys("sections")
          assert_equal 1, unique_keys.size

          constraint = unique_keys.first
          assert_equal "sections", constraint.table_name
          assert_equal "uniq_rails_79b901ffb4", constraint.name
          assert_equal ["position"], constraint.columns
          assert_equal false, constraint.deferrable
        end

        def test_add_unique_key_with_columns_and_using_index
          @connection.add_index :sections, [:position], name: "unique_index", unique: true

          assert_raises(ArgumentError) do
            @connection.add_unique_key :sections, [:position], using_index: "unique_index"
          end
        end

        def test_remove_unique_key
          assert_equal 0, @connection.unique_keys("sections").size

          @connection.add_unique_key :sections, [:position], name: "unique_section_position"
          assert_equal 1, @connection.unique_keys("sections").size
          @connection.remove_unique_key :sections, name: "unique_section_position"
          assert_equal 0, @connection.unique_keys("sections").size
        end

        def test_remove_non_existing_unique_key
          assert_raises(ArgumentError) do
            @connection.remove_unique_key :sections, name: "nonexistent"
          end
        end
      end
    end
  end
end
