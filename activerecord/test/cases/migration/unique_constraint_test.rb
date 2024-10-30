# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.lease_connection.supports_unique_constraints?
  module ActiveRecord
    class Migration
      class UniqueConstraintTest < ActiveRecord::TestCase
        include SchemaDumpingHelper

        class Section < ActiveRecord::Base
        end

        setup do
          @connection = ActiveRecord::Base.lease_connection
          @connection.create_table "sections", force: true do |t|
            t.integer "position", null: false
          end
        end

        teardown do
          @connection.drop_table "sections", if_exists: true
        end

        def test_unique_constraints
          unique_constraints = @connection.unique_constraints("test_unique_constraints")

          expected_constraints = [
            {
              name: "test_unique_constraints_position_deferrable_false",
              deferrable: false,
              column: ["position_1"]
            }, {
              name: "test_unique_constraints_position_deferrable_immediate",
              deferrable: :immediate,
              column: ["position_2"]
            }, {
              name: "test_unique_constraints_position_deferrable_deferred",
              deferrable: :deferred,
              column: ["position_3"]
            }, {
              name: "test_unique_constraints_position_nulls_not_distinct",
              nulls_not_distinct: true,
              column: ["position_4"]
            }
          ]

          assert_equal expected_constraints.size, unique_constraints.size

          expected_nulls_not_distinct = expected_constraints.pop

          expected_constraints.each do |expected_constraint|
            constraint = unique_constraints.find { |constraint| constraint.name == expected_constraint[:name] }
            assert_equal "test_unique_constraints", constraint.table_name
            assert_equal expected_constraint[:name], constraint.name
            assert_equal expected_constraint[:column], constraint.column
            assert_equal expected_constraint[:deferrable], constraint.deferrable
          end

          if supports_nulls_not_distinct?
            constraint = unique_constraints.find { |constraint| constraint.name == expected_nulls_not_distinct[:name] }
            assert_equal "test_unique_constraints", constraint.table_name
            assert_equal expected_nulls_not_distinct[:name], constraint.name
            assert_equal expected_nulls_not_distinct[:column], constraint.column
            assert_equal expected_nulls_not_distinct[:nulls_not_distinct], constraint.nulls_not_distinct
          end
        end

        def test_unique_constraints_scoped_to_schemas
          @connection.add_unique_constraint :sections, [:position]

          assert_no_changes -> { @connection.unique_constraints("sections").size } do
            @connection.create_schema "test_schema"
            @connection.create_table "test_schema.sections" do |t|
              t.integer :position
            end
            @connection.add_unique_constraint "test_schema.sections", [:position]
          end
        ensure
          @connection.drop_schema "test_schema"
        end

        def test_add_unique_constraint_without_deferrable
          @connection.add_unique_constraint :sections, [:position]

          unique_constraints = @connection.unique_constraints("sections")
          assert_equal 1, unique_constraints.size

          constraint = unique_constraints.first
          assert_equal "sections", constraint.table_name
          assert_equal "uniq_rails_1e07660b77", constraint.name
          assert_equal false, constraint.deferrable
        end

        def test_add_unique_constraint_with_deferrable_false
          @connection.add_unique_constraint :sections, [:position], deferrable: false

          unique_constraints = @connection.unique_constraints("sections")
          assert_equal 1, unique_constraints.size

          constraint = unique_constraints.first
          assert_equal "sections", constraint.table_name
          assert_equal "uniq_rails_1e07660b77", constraint.name
          assert_equal false, constraint.deferrable
        end

        def test_add_unique_constraint_with_deferrable_immediate
          @connection.add_unique_constraint :sections, [:position], deferrable: :immediate

          unique_constraints = @connection.unique_constraints("sections")
          assert_equal 1, unique_constraints.size

          constraint = unique_constraints.first
          assert_equal "sections", constraint.table_name
          assert_equal "uniq_rails_1e07660b77", constraint.name
          assert_equal :immediate, constraint.deferrable
        end

        def test_add_unique_constraint_with_deferrable_deferred
          @connection.add_unique_constraint :sections, [:position], deferrable: :deferred

          unique_constraints = @connection.unique_constraints("sections")
          assert_equal 1, unique_constraints.size

          constraint = unique_constraints.first
          assert_equal "sections", constraint.table_name
          assert_equal "uniq_rails_1e07660b77", constraint.name
          assert_equal :deferred, constraint.deferrable
        end

        def test_add_unique_constraint_with_deferrable_invalid
          error = assert_raises(ArgumentError) do
            @connection.add_unique_constraint :sections, [:position], deferrable: true
          end

          assert_equal "deferrable must be `:immediate` or `:deferred`, got: `true`", error.message
        end

        def test_added_deferrable_initially_immediate_unique_constraint
          @connection.add_unique_constraint :sections, [:position], deferrable: :immediate, name: "unique_section_position"

          section = Section.create!(position: 1)

          assert_raises(ActiveRecord::StatementInvalid) do
            Section.transaction(requires_new: true) do
              Section.create!(position: 1)
              section.update!(position: 2)
            end
          end

          assert_nothing_raised do
            Section.transaction(requires_new: true) do
              Section.lease_connection.exec_query("SET CONSTRAINTS unique_section_position DEFERRED")
              Section.create!(position: 1)
              section.update!(position: 2)

              # NOTE: Clear `SET CONSTRAINTS` statement at the end of transaction.
              raise ActiveRecord::Rollback
            end
          end
        end

        def test_add_unique_constraint_with_name_and_using_index
          @connection.add_index :sections, [:position], name: "unique_index", unique: true
          @connection.add_unique_constraint :sections, name: "unique_constraint", deferrable: :immediate, using_index: "unique_index"

          unique_constraints = @connection.unique_constraints("sections")
          assert_equal 1, unique_constraints.size

          constraint = unique_constraints.first
          assert_equal "sections", constraint.table_name
          assert_equal "unique_constraint", constraint.name
          assert_equal ["position"], constraint.column
          assert_equal :immediate, constraint.deferrable
        end

        def test_add_unique_constraint_with_only_using_index
          @connection.add_index :sections, [:position], name: "unique_index", unique: true
          @connection.add_unique_constraint :sections, using_index: "unique_index"

          unique_constraints = @connection.unique_constraints("sections")
          assert_equal 1, unique_constraints.size

          constraint = unique_constraints.first
          assert_equal "sections", constraint.table_name
          assert_equal "uniq_rails_79b901ffb4", constraint.name
          assert_equal ["position"], constraint.column
          assert_equal false, constraint.deferrable
        end

        def test_add_unique_constraint_with_columns_and_using_index
          @connection.add_index :sections, [:position], name: "unique_index", unique: true

          assert_raises(ArgumentError) do
            @connection.add_unique_constraint :sections, [:position], using_index: "unique_index"
          end
        end

        def test_remove_unique_constraint
          @connection.add_unique_constraint :sections, [:position], name: :unique_section_position
          assert_equal 1, @connection.unique_constraints("sections").size
          @connection.remove_unique_constraint :sections, name: :unique_section_position
          assert_empty @connection.unique_constraints("sections")
        end

        def test_remove_unique_constraint_by_column
          @connection.add_unique_constraint :sections, [:position]
          assert_equal 1, @connection.unique_constraints("sections").size
          @connection.remove_unique_constraint :sections, [:position]
          assert_empty @connection.unique_constraints("sections")
        end

        def test_remove_non_existing_unique_constraint
          assert_raises(ArgumentError, match: /Table 'sections' has no unique constraint/) do
            @connection.remove_unique_constraint :sections, name: "nonexistent"
          end
        end

        def test_renamed_unique_constraint
          @connection.add_unique_constraint :sections, [:position]
          @connection.rename_column :sections, :position, :new_position

          unique_constraints = @connection.unique_constraints("sections")
          assert_equal 1, unique_constraints.size

          constraint = unique_constraints.first
          assert_equal "sections", constraint.table_name
          assert_equal ["new_position"], constraint.column
        end
      end
    end
  end
end
