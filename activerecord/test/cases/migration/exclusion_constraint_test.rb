# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.lease_connection.supports_exclusion_constraints?
  module ActiveRecord
    class Migration
      class ExclusionConstraintTest < ActiveRecord::TestCase
        include SchemaDumpingHelper

        class Invoice < ActiveRecord::Base
        end

        setup do
          @connection = ActiveRecord::Base.lease_connection
          @connection.create_table "invoices", force: true do |t|
            t.date :start_date
            t.date :end_date
          end
        end

        teardown do
          @connection.drop_table "invoices", if_exists: true
        end

        def test_exclusion_constraints
          expected_exclusion_constraints = [
            {
              table_name: "test_exclusion_constraints",
              name: "test_exclusion_constraints_date_overlap",
              expression: "daterange(start_date, end_date) WITH &&",
              where: "(start_date IS NOT NULL) AND (end_date IS NOT NULL)",
              using: :gist,
              deferrable: false
            }, {
              table_name: "test_exclusion_constraints",
              name: "test_exclusion_constraints_valid_overlap",
              expression: "daterange(valid_from, valid_to) WITH &&",
              where: "(valid_from IS NOT NULL) AND (valid_to IS NOT NULL)",
              using: :gist,
              deferrable: :immediate
            }, {
              table_name: "test_exclusion_constraints",
              name: "test_exclusion_constraints_transaction_overlap",
              expression: "daterange(transaction_from, transaction_to) WITH &&",
              where: "(transaction_from IS NOT NULL) AND (transaction_to IS NOT NULL)",
              using: :gist,
              deferrable: :deferred
            }
          ]

          exclusion_constraints = @connection.exclusion_constraints("test_exclusion_constraints")
          assert_equal expected_exclusion_constraints.size, exclusion_constraints.size

          expected_exclusion_constraints.each do |expected_constraint|
            constraint = exclusion_constraints.find { |constraint| constraint.name == expected_constraint[:name] }
            assert_equal expected_constraint[:table_name], constraint.table_name
            assert_equal expected_constraint[:name], constraint.name
            assert_equal expected_constraint[:expression], constraint.expression
            assert_equal expected_constraint[:using], constraint.using
            assert_equal expected_constraint[:where], constraint.where
            assert_equal expected_constraint[:deferrable], constraint.deferrable
          end
        end

        def test_exclusion_constraints_scoped_to_schemas
          @connection.add_exclusion_constraint :invoices, "daterange(start_date, end_date) WITH &&", using: :gist

          assert_no_changes -> { @connection.exclusion_constraints("invoices").size } do
            @connection.create_schema "test_schema"
            @connection.create_table "test_schema.invoices" do |t|
              t.date :start_date
              t.date :end_date
            end
            @connection.add_exclusion_constraint "test_schema.invoices", "daterange(start_date, end_date) WITH &&", using: :gist
          end
        ensure
          @connection.drop_schema "test_schema"
        end

        def test_add_exclusion_constraint
          @connection.add_exclusion_constraint :invoices, "daterange(start_date, end_date) WITH &&", using: :gist

          exclusion_constraints = @connection.exclusion_constraints("invoices")
          assert_equal 1, exclusion_constraints.size

          constraint = exclusion_constraints.first
          assert_equal "invoices", constraint.table_name
          assert_equal "excl_rails_74c9160f55", constraint.name
          assert_equal false, constraint.deferrable
          assert_equal "daterange(start_date, end_date) WITH &&", constraint.expression
        end

        def test_add_exclusion_constraint_deferrable_false
          @connection.add_exclusion_constraint :invoices, "daterange(start_date, end_date) WITH &&", using: :gist, deferrable: false

          exclusion_constraints = @connection.exclusion_constraints("invoices")
          assert_equal 1, exclusion_constraints.size

          constraint = exclusion_constraints.first
          assert_equal "invoices", constraint.table_name
          assert_equal "excl_rails_74c9160f55", constraint.name
          assert_equal false, constraint.deferrable
          assert_equal "daterange(start_date, end_date) WITH &&", constraint.expression
        end

        def test_add_exclusion_constraint_deferrable_initially_immediate
          @connection.add_exclusion_constraint :invoices, "daterange(start_date, end_date) WITH &&", using: :gist, deferrable: :immediate

          exclusion_constraints = @connection.exclusion_constraints("invoices")
          assert_equal 1, exclusion_constraints.size

          constraint = exclusion_constraints.first
          assert_equal "invoices", constraint.table_name
          assert_equal "excl_rails_74c9160f55", constraint.name
          assert_equal :immediate, constraint.deferrable
          assert_equal "daterange(start_date, end_date) WITH &&", constraint.expression
        end

        def test_add_exclusion_constraint_deferrable_initially_deferred
          @connection.add_exclusion_constraint :invoices, "daterange(start_date, end_date) WITH &&", using: :gist, deferrable: :deferred

          exclusion_constraints = @connection.exclusion_constraints("invoices")
          assert_equal 1, exclusion_constraints.size

          constraint = exclusion_constraints.first
          assert_equal "invoices", constraint.table_name
          assert_equal "excl_rails_74c9160f55", constraint.name
          assert_equal :deferred, constraint.deferrable
          assert_equal "daterange(start_date, end_date) WITH &&", constraint.expression
        end

        def test_add_exclusion_constraint_deferrable_invalid
          error = assert_raises(ArgumentError) do
            @connection.add_exclusion_constraint :invoices, "daterange(start_date, end_date) WITH &&", using: :gist, deferrable: true
          end

          assert_equal "deferrable must be `:immediate` or `:deferred`, got: `true`", error.message
        end

        def test_added_exclusion_constraint_ensures_valid_values
          @connection.add_exclusion_constraint :invoices, "daterange(start_date, end_date) WITH &&", using: :gist

          Invoice.create(start_date: "2020-01-01", end_date: "2021-01-01")

          assert_raises(ActiveRecord::StatementInvalid) do
            Invoice.create(start_date: "2020-12-31", end_date: "2021-01-01")
          end
        end

        def test_added_deferrable_initially_immediate_exclusion_constraint
          @connection.add_exclusion_constraint :invoices, "daterange(start_date, end_date) WITH &&", using: :gist, deferrable: :immediate, name: "invoices_date_overlap"

          invoice = Invoice.create(start_date: "2020-01-01", end_date: "2021-01-01")

          assert_raises(ActiveRecord::StatementInvalid) do
            Invoice.transaction(requires_new: true) do
              Invoice.create!(start_date: "2020-12-31", end_date: "2021-01-01")
            end
          end

          assert_nothing_raised do
            Invoice.transaction(requires_new: true) do
              Invoice.lease_connection.set_constraints(:deferred, "invoices_date_overlap")
              Invoice.create!(start_date: "2020-12-31", end_date: "2021-01-01")
              invoice.update!(end_date: "2020-12-31")

              # NOTE: Clear `SET CONSTRAINTS` statement at the end of transaction.
              raise ActiveRecord::Rollback
            end
          end
        end

        def test_remove_exclusion_constraint
          assert_equal 0, @connection.exclusion_constraints("invoices").size

          @connection.add_exclusion_constraint :invoices, "daterange(start_date, end_date) WITH &&", using: :gist, name: "invoices_date_overlap"
          assert_equal 1, @connection.exclusion_constraints("invoices").size
          @connection.remove_exclusion_constraint :invoices, name: "invoices_date_overlap"
          assert_equal 0, @connection.exclusion_constraints("invoices").size
        end

        def test_remove_non_existing_exclusion_constraint
          assert_raises(ArgumentError) do
            @connection.remove_exclusion_constraint :invoices, name: "nonexistent"
          end
        end
      end
    end
  end
end
