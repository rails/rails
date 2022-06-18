# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.connection.supports_exclusion_constraints?
  module ActiveRecord
    class Migration
      class ExclusionConstraintTest < ActiveRecord::TestCase
        include SchemaDumpingHelper

        class Invoice < ActiveRecord::Base
        end

        setup do
          @connection = ActiveRecord::Base.connection
          @connection.create_table "invoices", force: true do |t|
            t.date :start_date
            t.date :end_date
          end
        end

        teardown do
          @connection.drop_table "invoices", if_exists: true
        end

        def test_exclusion_constraints
          exclusion_constraints = @connection.exclusion_constraints("test_exclusion_constraints")
          assert_equal 1, exclusion_constraints.size

          constraint = exclusion_constraints.first
          assert_equal "test_exclusion_constraints", constraint.table_name
          assert_equal "test_exclusion_constraints_date_overlap", constraint.name
          assert_equal "daterange(start_date, end_date) WITH &&", constraint.expression
          assert_equal :gist, constraint.using
          assert_equal "(start_date IS NOT NULL) AND (end_date IS NOT NULL)", constraint.where
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

          assert_equal "daterange(start_date, end_date) WITH &&", constraint.expression
        end

        def test_added_exclusion_constraint_ensures_valid_values
          @connection.add_exclusion_constraint :invoices, "daterange(start_date, end_date) WITH &&", using: :gist

          Invoice.create(start_date: "2020-01-01", end_date: "2021-01-01")

          assert_raises(ActiveRecord::StatementInvalid) do
            Invoice.create(start_date: "2020-12-31", end_date: "2021-01-01")
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
