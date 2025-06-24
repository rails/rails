# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.lease_connection.supports_foreign_keys?
  module ActiveRecord
    class Migration
      class ForeignKeyInCreateTest < ActiveRecord::TestCase
        def test_foreign_keys
          foreign_keys = ActiveRecord::Base.lease_connection.foreign_keys("fk_test_has_fk")
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal "fk_test_has_fk", fk.from_table
          assert_equal "fk_test_has_pk", fk.to_table
          assert_equal "fk_id", fk.column
          assert_equal "pk_id", fk.primary_key
          assert_equal "fk_name", fk.name unless current_adapter?(:SQLite3Adapter)
        end
      end

      class ForeignKeyChangeColumnTest < ActiveRecord::TestCase
        self.use_transactional_tests = false

        class Rocket < ActiveRecord::Base
          has_many :astronauts
        end

        class Astronaut < ActiveRecord::Base
          belongs_to :rocket
        end

        class CreateRocketsMigration < ActiveRecord::Migration::Current
          def change
            create_table :rockets do |t|
              t.string :name
            end

            create_table :astronauts do |t|
              t.string :name
              t.references :rocket, foreign_key: true
            end
          end
        end

        def setup
          @connection = ActiveRecord::Base.lease_connection
          @migration = CreateRocketsMigration.new
          silence_stream($stdout) { @migration.migrate(:up) }
          Rocket.reset_table_name
          Rocket.reset_column_information
          Astronaut.reset_table_name
          Astronaut.reset_column_information
        end

        def teardown
          silence_stream($stdout) { @migration.migrate(:down) }
          Rocket.reset_table_name
          Rocket.reset_column_information
          Astronaut.reset_table_name
          Astronaut.reset_column_information
        end

        def test_change_column_of_parent_table
          rocket = Rocket.create!(name: "myrocket")
          rocket.astronauts << Astronaut.create!

          @connection.change_column_null Rocket.table_name, :name, false

          foreign_keys = @connection.foreign_keys(Astronaut.table_name)
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal "myrocket", Rocket.first.name
          assert_equal Astronaut.table_name, fk.from_table
          assert_equal Rocket.table_name, fk.to_table
        end

        def test_rename_column_of_child_table
          rocket = Rocket.create!(name: "myrocket")
          rocket.astronauts << Astronaut.create!

          @connection.rename_column Astronaut.table_name, :name, :astronaut_name

          foreign_keys = @connection.foreign_keys(Astronaut.table_name)
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal "myrocket", Rocket.first.name
          assert_equal Astronaut.table_name, fk.from_table
          assert_equal Rocket.table_name, fk.to_table
        end

        def test_rename_reference_column_of_child_table
          if current_adapter?(:Mysql2Adapter, :TrilogyAdapter) && !@connection.send(:supports_rename_index?)
            skip "Cannot drop index, needed in a foreign key constraint"
          end

          rocket = Rocket.create!(name: "myrocket")
          rocket.astronauts << Astronaut.create!

          @connection.rename_column Astronaut.table_name, :rocket_id, :new_rocket_id

          foreign_keys = @connection.foreign_keys(Astronaut.table_name)
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal "myrocket", Rocket.first.name
          assert_equal Astronaut.table_name, fk.from_table
          assert_equal Rocket.table_name, fk.to_table
          assert_equal "new_rocket_id", fk.options[:column]
        end

        def test_remove_reference_column_of_child_table
          rocket = Rocket.create!(name: "myrocket")
          rocket.astronauts << Astronaut.create!

          @connection.remove_column Astronaut.table_name, :rocket_id

          assert_empty @connection.foreign_keys(Astronaut.table_name)
        end

        def test_remove_foreign_key_by_column
          rocket = Rocket.create!(name: "myrocket")
          rocket.astronauts << Astronaut.create!

          @connection.remove_foreign_key Astronaut.table_name, column: :rocket_id

          assert_empty @connection.foreign_keys(Astronaut.table_name)
        end

        def test_remove_foreign_key_by_column_in_change_table
          rocket = Rocket.create!(name: "myrocket")
          rocket.astronauts << Astronaut.create!

          @connection.change_table Astronaut.table_name do |t|
            t.remove_foreign_key column: :rocket_id
          end

          assert_empty @connection.foreign_keys(Astronaut.table_name)
        end
      end

      class ForeignKeyChangeColumnWithPrefixTest < ForeignKeyChangeColumnTest
        setup do
          ActiveRecord::Base.table_name_prefix = "p_"
        end

        teardown do
          ActiveRecord::Base.table_name_prefix = nil
        end
      end

      class ForeignKeyChangeColumnWithSuffixTest < ForeignKeyChangeColumnTest
        setup do
          ActiveRecord::Base.table_name_suffix = "_s"
        end

        teardown do
          ActiveRecord::Base.table_name_suffix = nil
        end
      end
    end
  end

  module ActiveRecord
    class Migration
      class ForeignKeyTest < ActiveRecord::TestCase
        include SchemaDumpingHelper
        include ActiveSupport::Testing::Stream

        class Rocket < ActiveRecord::Base
        end

        class Astronaut < ActiveRecord::Base
        end

        setup do
          @connection = ActiveRecord::Base.lease_connection
          @connection.create_table "rockets", force: true do |t|
            t.string :name
          end

          @connection.create_table "astronauts", force: true do |t|
            t.string :name
            t.references :rocket, type: :bigint
            t.references :favorite_rocket
          end
        end

        teardown do
          @connection.drop_table "astronauts", if_exists: true rescue nil
          @connection.drop_table "rockets", if_exists: true rescue nil
        end

        def test_foreign_keys
          foreign_keys = @connection.foreign_keys("fk_test_has_fk")
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal "fk_test_has_fk", fk.from_table
          assert_equal "fk_test_has_pk", fk.to_table
          assert_equal "fk_id", fk.column
          assert_equal "pk_id", fk.primary_key
          assert_equal "fk_name", fk.name unless current_adapter?(:SQLite3Adapter)
        end

        def test_add_foreign_key_inferes_column
          @connection.add_foreign_key :astronauts, :rockets

          foreign_keys = @connection.foreign_keys("astronauts")
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal "astronauts", fk.from_table
          assert_equal "rockets", fk.to_table
          assert_equal "rocket_id", fk.column
          assert_equal "id", fk.primary_key
          assert_equal "fk_rails_78146ddd2e", fk.name unless current_adapter?(:SQLite3Adapter)
        end

        def test_add_foreign_key_with_column
          @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id"

          foreign_keys = @connection.foreign_keys("astronauts")
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal "astronauts", fk.from_table
          assert_equal "rockets", fk.to_table
          assert_equal "rocket_id", fk.column
          assert_equal "id", fk.primary_key
          assert_equal "fk_rails_78146ddd2e", fk.name unless current_adapter?(:SQLite3Adapter)
        end

        def test_add_foreign_key_with_if_not_exists_to_already_referenced_table
          @connection.add_foreign_key :astronauts, :rockets, column: "favorite_rocket_id"
          @connection.add_foreign_key :astronauts, :rockets, if_not_exists: true

          foreign_keys = @connection.foreign_keys("astronauts")
          assert_equal 2, foreign_keys.size
          assert foreign_keys.all? { |fk| fk.to_table == "rockets" }
          assert_equal ["favorite_rocket_id", "rocket_id"], foreign_keys.map(&:column).sort
        end

        def test_add_foreign_key_with_if_not_exists_considers_primary_key_option
          @connection.add_column :rockets, :id_for_type_change, :bigint

          # Is needed to be able to reference by foreign key
          @connection.add_index :rockets, :id_for_type_change, unique: true

          @connection.add_foreign_key :astronauts, :rockets
          @connection.add_foreign_key(:astronauts, :rockets, primary_key: :id_for_type_change,
            name: "custom_pk",  if_not_exists: true)

          foreign_keys = @connection.foreign_keys("astronauts")
          assert_equal 2, foreign_keys.size
          assert foreign_keys.all? { |fk| fk.to_table == "rockets" }
          assert_equal ["id", "id_for_type_change"], foreign_keys.map(&:primary_key).sort
        end

        def test_add_foreign_key_with_non_standard_primary_key
          @connection.create_table :space_shuttles, id: false, force: true do |t|
            t.bigint :pk, primary_key: true
          end

          @connection.add_foreign_key(:astronauts, :space_shuttles,
            column: "rocket_id", primary_key: "pk", name: "custom_pk")

          foreign_keys = @connection.foreign_keys("astronauts")
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal "astronauts", fk.from_table
          assert_equal "space_shuttles", fk.to_table
          assert_equal "pk", fk.primary_key
        ensure
          @connection.remove_foreign_key :astronauts, name: "custom_pk", to_table: "space_shuttles"
          @connection.drop_table :space_shuttles
        end

        def test_add_on_delete_restrict_foreign_key
          @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", on_delete: :restrict

          foreign_keys = @connection.foreign_keys("astronauts")
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
            # ON DELETE RESTRICT is the default on MySQL
            assert_nil fk.on_delete
          else
            assert_equal :restrict, fk.on_delete
          end
        end

        def test_add_on_delete_cascade_foreign_key
          @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", on_delete: :cascade

          foreign_keys = @connection.foreign_keys("astronauts")
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal :cascade, fk.on_delete
        end

        def test_add_on_delete_nullify_foreign_key
          @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", on_delete: :nullify

          foreign_keys = @connection.foreign_keys("astronauts")
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal :nullify, fk.on_delete
        end

        def test_on_update_and_on_delete_raises_with_invalid_values
          assert_raises ArgumentError do
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", on_delete: :invalid
          end

          assert_raises ArgumentError do
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", on_update: :invalid
          end
        end

        def test_add_foreign_key_with_on_update
          @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", on_update: :nullify

          foreign_keys = @connection.foreign_keys("astronauts")
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal :nullify, fk.on_update
        end

        def test_add_foreign_key_with_non_existent_from_table_raises
          e = assert_raises StatementInvalid do
            @connection.add_foreign_key :missions, :rockets
          end
          assert_match(/missions/, e.message)
        end

        def test_add_foreign_key_with_non_existent_to_table_raises
          e = assert_raises StatementInvalid do
            @connection.add_foreign_key :missions, :rockets
          end
          assert_match(/missions/, e.message)
        end

        def test_foreign_key_exists
          @connection.add_foreign_key :astronauts, :rockets

          assert @connection.foreign_key_exists?(:astronauts, :rockets)
          assert_not @connection.foreign_key_exists?(:astronauts, :stars)
        end

        def test_foreign_key_exists_referencing_table_having_keyword_as_name
          @connection.create_table :user, force: true
          @connection.add_column :rockets, :user_id, :bigint
          @connection.add_foreign_key :rockets, :user
          assert @connection.foreign_key_exists?(:rockets, :user)
        ensure
          @connection.remove_foreign_key :rockets, :user
          @connection.drop_table :user
        end

        def test_foreign_key_exists_by_column
          @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id"

          assert @connection.foreign_key_exists?(:astronauts, column: "rocket_id")
          assert_not @connection.foreign_key_exists?(:astronauts, column: "star_id")
        end

        def test_foreign_key_exists_by_name
          skip if current_adapter?(:SQLite3Adapter)

          @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", name: "fancy_named_fk"

          assert @connection.foreign_key_exists?(:astronauts, name: "fancy_named_fk")
          assert_not @connection.foreign_key_exists?(:astronauts, name: "other_fancy_named_fk")
        end

        def test_foreign_key_exists_in_change_table
          @connection.change_table(:astronauts) do |t|
            t.foreign_key :rockets, column: "rocket_id", name: "fancy_named_fk"

            assert t.foreign_key_exists?(column: "rocket_id")
            assert_not t.foreign_key_exists?(column: "star_id")

            unless current_adapter?(:SQLite3Adapter)
              assert t.foreign_key_exists?(name: "fancy_named_fk")
              assert_not t.foreign_key_exists?(name: "other_fancy_named_fk")
            end
          end
        end

        if supports_sql_standard_drop_constraint?
          def test_remove_constraint
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", name: "fancy_named_fk"

            assert_equal 1, @connection.foreign_keys("astronauts").size
            @connection.remove_constraint :astronauts, "fancy_named_fk"
            assert_equal [], @connection.foreign_keys("astronauts")
          end
        end

        def test_remove_foreign_key_inferes_column
          @connection.add_foreign_key :astronauts, :rockets

          assert_equal 1, @connection.foreign_keys("astronauts").size
          @connection.remove_foreign_key :astronauts, :rockets
          assert_equal [], @connection.foreign_keys("astronauts")
        end

        def test_remove_foreign_key_by_column
          @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id"

          assert_equal 1, @connection.foreign_keys("astronauts").size
          @connection.remove_foreign_key :astronauts, column: "rocket_id"
          assert_equal [], @connection.foreign_keys("astronauts")
        end

        def test_remove_foreign_key_by_symbol_column
          @connection.add_foreign_key :astronauts, :rockets, column: :rocket_id

          assert_equal 1, @connection.foreign_keys("astronauts").size
          @connection.remove_foreign_key :astronauts, column: :rocket_id
          assert_equal [], @connection.foreign_keys("astronauts")
        end

        def test_remove_foreign_key_by_name
          skip if current_adapter?(:SQLite3Adapter)

          @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", name: "fancy_named_fk"

          assert_equal 1, @connection.foreign_keys("astronauts").size
          @connection.remove_foreign_key :astronauts, name: "fancy_named_fk"
          assert_equal [], @connection.foreign_keys("astronauts")
        end

        def test_remove_foreign_key_if_exists_and_custom_column
          @connection.add_column :astronauts, :myrocket_id, :bigint
          @connection.add_foreign_key :astronauts, :rockets
          assert_equal 1, @connection.foreign_keys("astronauts").size

          @connection.remove_foreign_key :astronauts, :rockets, column: :myrocket_id, if_exists: true
          assert_equal 1, @connection.foreign_keys("astronauts").size
        end

        def test_remove_foreign_non_existing_foreign_key_raises
          e = assert_raises ArgumentError do
            @connection.remove_foreign_key :astronauts, :rockets
          end
          assert_equal "Table 'astronauts' has no foreign key for rockets", e.message
        end

        def test_remove_foreign_key_by_the_select_one_on_the_same_table
          @connection.add_foreign_key :astronauts, :rockets
          @connection.add_reference :astronauts, :myrocket, foreign_key: { to_table: :rockets }

          assert_equal 2, @connection.foreign_keys("astronauts").size

          @connection.remove_foreign_key :astronauts, :rockets, column: "myrocket_id"

          assert_equal [["astronauts", "rockets", "rocket_id"]],
            @connection.foreign_keys("astronauts").map { |fk| [fk.from_table, fk.to_table, fk.column] }
        end

        def test_remove_foreign_key_with_restrict_action
          @connection.add_foreign_key :astronauts, :rockets, on_delete: :restrict
          assert_equal 1, @connection.foreign_keys("astronauts").size
          @connection.remove_foreign_key :astronauts, :rockets, on_delete: :restrict
          assert_empty @connection.foreign_keys("astronauts")
        end

        if ActiveRecord::Base.lease_connection.supports_validate_constraints?
          def test_add_invalid_foreign_key
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", validate: false

            foreign_keys = @connection.foreign_keys("astronauts")
            assert_equal 1, foreign_keys.size

            fk = foreign_keys.first
            assert_not_predicate fk, :validated?
          end

          def test_validate_foreign_key_infers_column
            @connection.add_foreign_key :astronauts, :rockets, validate: false
            assert_not_predicate @connection.foreign_keys("astronauts").first, :validated?

            @connection.validate_foreign_key :astronauts, :rockets
            assert_predicate @connection.foreign_keys("astronauts").first, :validated?
          end

          def test_validate_foreign_key_by_column
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", validate: false
            assert_not_predicate @connection.foreign_keys("astronauts").first, :validated?

            @connection.validate_foreign_key :astronauts, column: "rocket_id"
            assert_predicate @connection.foreign_keys("astronauts").first, :validated?
          end

          def test_validate_foreign_key_by_symbol_column
            @connection.add_foreign_key :astronauts, :rockets, column: :rocket_id, validate: false
            assert_not_predicate @connection.foreign_keys("astronauts").first, :validated?

            @connection.validate_foreign_key :astronauts, column: :rocket_id
            assert_predicate @connection.foreign_keys("astronauts").first, :validated?
          end

          def test_validate_foreign_key_by_name
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", name: "fancy_named_fk", validate: false
            assert_not_predicate @connection.foreign_keys("astronauts").first, :validated?

            @connection.validate_foreign_key :astronauts, name: "fancy_named_fk"
            assert_predicate @connection.foreign_keys("astronauts").first, :validated?
          end

          def test_validate_foreign_non_existing_foreign_key_raises
            assert_raises ArgumentError do
              @connection.validate_foreign_key :astronauts, :rockets
            end
          end

          def test_validate_constraint_by_name
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", name: "fancy_named_fk", validate: false

            @connection.validate_constraint :astronauts, "fancy_named_fk"
            assert_predicate @connection.foreign_keys("astronauts").first, :validated?
          end

          def test_schema_dumping_with_validate_false
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", validate: false

            output = dump_table_schema "astronauts"

            assert_match %r{\s+add_foreign_key "astronauts", "rockets", validate: false$}, output
          end

          def test_schema_dumping_with_validate_true
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", validate: true

            output = dump_table_schema "astronauts"

            assert_match %r{\s+add_foreign_key "astronauts", "rockets"$}, output
          end
        else
          # Foreign key should still be created, but should not be invalid
          def test_add_invalid_foreign_key
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", validate: false

            foreign_keys = @connection.foreign_keys("astronauts")
            assert_equal 1, foreign_keys.size

            fk = foreign_keys.first
            assert_predicate fk, :validated?
          end
        end

        if ActiveRecord::Base.lease_connection.supports_deferrable_constraints?
          def test_deferrable_foreign_key
            assert_queries_match(/\("id"\)\s+DEFERRABLE INITIALLY IMMEDIATE\W*\z/i) do
              @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", deferrable: :immediate
            end

            foreign_keys = @connection.foreign_keys("astronauts")
            assert_equal 1, foreign_keys.size

            fk = foreign_keys.first
            assert_equal :immediate, fk.deferrable
          end

          def test_not_deferrable_foreign_key
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", deferrable: false

            foreign_keys = @connection.foreign_keys("astronauts")
            assert_equal 1, foreign_keys.size

            fk = foreign_keys.first
            assert_equal false, fk.deferrable
          end

          def test_deferrable_initially_deferred_foreign_key
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", deferrable: :deferred

            foreign_keys = @connection.foreign_keys("astronauts")
            assert_equal 1, foreign_keys.size

            fk = foreign_keys.first
            assert_equal :deferred, fk.deferrable
          end

          def test_deferrable_initially_immediate_foreign_key
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", deferrable: :immediate

            foreign_keys = @connection.foreign_keys("astronauts")
            assert_equal 1, foreign_keys.size

            fk = foreign_keys.first
            assert_equal :immediate, fk.deferrable
          end

          def test_schema_dumping_with_defferable
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", deferrable: :immediate

            output = dump_table_schema "astronauts"

            assert_match %r{\s+add_foreign_key "astronauts", "rockets", deferrable: :immediate$}, output
          end

          def test_schema_dumping_with_disabled_defferable
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", deferrable: false

            output = dump_table_schema "astronauts"

            assert_match %r{\s+add_foreign_key "astronauts", "rockets"$}, output
          end

          def test_schema_dumping_with_defferable_initially_deferred
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", deferrable: :deferred

            output = dump_table_schema "astronauts"

            assert_match %r{\s+add_foreign_key "astronauts", "rockets", deferrable: :deferred$}, output
          end

          def test_schema_dumping_with_defferable_initially_immediate
            @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", deferrable: :immediate

            output = dump_table_schema "astronauts"

            assert_match %r{\s+add_foreign_key "astronauts", "rockets", deferrable: :immediate$}, output
          end

          def test_schema_dumping_with_special_chars_deferrable
            @connection.add_reference :astronauts, :røcket, foreign_key: { to_table: :rockets, deferrable: :deferred }

            output = dump_table_schema "astronauts"

            assert_match %r{\s+add_foreign_key "astronauts", "rockets", column: "røcket_id", deferrable: :deferred$}, output
          end
        end

        def test_does_not_create_foreign_keys_when_bypassed_by_config
          require "active_record/connection_adapters/sqlite3_adapter"
          connection = ActiveRecord::ConnectionAdapters::SQLite3Adapter.new(
            adapter: "sqlite3",
            database: ":memory:",
            foreign_keys: false,
          )

          connection.create_table "rockets", force: true do |t|
            t.string :name
          end
          connection.create_table "astronauts", force: true do |t|
            t.string :name
            t.references :rocket
          end

          connection.add_foreign_key :astronauts, :rockets

          foreign_keys = connection.foreign_keys("astronauts")
          assert_equal 0, foreign_keys.size
        end

        def test_schema_dumping
          @connection.add_foreign_key :astronauts, :rockets
          output = dump_table_schema "astronauts"
          assert_match %r{\s+add_foreign_key "astronauts", "rockets"$}, output
        end

        def test_schema_dumping_with_options
          output = dump_table_schema "fk_test_has_fk"
          if current_adapter?(:SQLite3Adapter)
            assert_match %r{\s+add_foreign_key "fk_test_has_fk", "fk_test_has_pk", column: "fk_id", primary_key: "pk_id"$}, output
          else
            assert_match %r{\s+add_foreign_key "fk_test_has_fk", "fk_test_has_pk", column: "fk_id", primary_key: "pk_id", name: "fk_name"$}, output
          end
        end

        def test_schema_dumping_with_custom_fk_ignore_pattern
          original_pattern = ActiveRecord::SchemaDumper.fk_ignore_pattern
          ActiveRecord::SchemaDumper.fk_ignore_pattern = /^ignored_/
          @connection.add_foreign_key :astronauts, :rockets, name: :ignored_fk_astronauts_rockets

          output = dump_table_schema "astronauts"
          assert_match %r{\s+add_foreign_key "astronauts", "rockets"$}, output

          ActiveRecord::SchemaDumper.fk_ignore_pattern = original_pattern
        end

        def test_schema_dumping_on_delete_and_on_update_options
          @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", on_delete: :nullify, on_update: :cascade

          output = dump_table_schema "astronauts"
          assert_match %r{\s+add_foreign_key "astronauts",.+on_update: :cascade,.+on_delete: :nullify$}, output
        end

        class CreateCitiesAndHousesMigration < ActiveRecord::Migration::Current
          def change
            create_table("cities") { |t| }

            create_table("houses") do |t|
              t.references :city
            end
            add_foreign_key :houses, :cities, column: "city_id"

            # remove and re-add to test that schema is updated and not accidentally cached
            remove_foreign_key :houses, :cities
            add_foreign_key :houses, :cities, column: "city_id", on_delete: :cascade
          end
        end

        def test_add_foreign_key_is_reversible
          @connection.drop_table("cities", if_exists: true)
          @connection.drop_table("houses", if_exists: true)

          migration = CreateCitiesAndHousesMigration.new
          silence_stream($stdout) { migration.migrate(:up) }
          assert_equal 1, @connection.foreign_keys("houses").size
          silence_stream($stdout) { migration.migrate(:down) }
        ensure
          @connection.drop_table("cities", if_exists: true)
          @connection.drop_table("houses", if_exists: true)
        end

        def test_foreign_key_constraint_is_not_cached_incorrectly
          @connection.drop_table("cities", if_exists: true)
          @connection.drop_table("houses", if_exists: true)

          migration = CreateCitiesAndHousesMigration.new
          silence_stream($stdout) { migration.migrate(:up) }
          output = dump_table_schema "houses"
          assert_match %r{\s+add_foreign_key "houses",.+on_delete: :cascade$}, output
          silence_stream($stdout) { migration.migrate(:down) }
        ensure
          @connection.drop_table("cities", if_exists: true)
          @connection.drop_table("houses", if_exists: true)
        end

        class CreateSchoolsAndClassesMigration < ActiveRecord::Migration::Current
          def change
            create_table(:schools)

            create_table(:classes) do |t|
              t.references :school
            end
            add_foreign_key :classes, :schools, validate: true
          end
        end

        def test_add_foreign_key_with_prefix
          ActiveRecord::Base.table_name_prefix = "p_"
          migration = CreateSchoolsAndClassesMigration.new
          silence_stream($stdout) { migration.migrate(:up) }
          assert_equal 1, @connection.foreign_keys("p_classes").size
        ensure
          silence_stream($stdout) { migration.migrate(:down) }
          ActiveRecord::Base.table_name_prefix = nil
        end

        def test_add_foreign_key_with_suffix
          ActiveRecord::Base.table_name_suffix = "_s"
          migration = CreateSchoolsAndClassesMigration.new
          silence_stream($stdout) { migration.migrate(:up) }
          assert_equal 1, @connection.foreign_keys("classes_s").size
        ensure
          silence_stream($stdout) { migration.migrate(:down) }
          ActiveRecord::Base.table_name_suffix = nil
        end

        def test_remove_foreign_key_with_if_exists_not_set
          @connection.add_foreign_key :astronauts, :rockets
          assert_equal 1, @connection.foreign_keys("astronauts").size

          @connection.remove_foreign_key :astronauts, :rockets
          assert_equal [], @connection.foreign_keys("astronauts")

          error = assert_raises do
            @connection.remove_foreign_key :astronauts, :rockets
          end

          assert_equal("Table 'astronauts' has no foreign key for rockets", error.message)
        end

        def test_remove_foreign_key_with_if_exists_set
          @connection.add_foreign_key :astronauts, :rockets
          assert_equal 1, @connection.foreign_keys("astronauts").size

          @connection.remove_foreign_key :astronauts, :rockets, if_exists: true
          assert_equal [], @connection.foreign_keys("astronauts")

          assert_nothing_raised do
            @connection.remove_foreign_key :astronauts, :rockets, if_exists: true
          end
        end

        def test_add_foreign_key_with_if_not_exists_not_set
          @connection.add_foreign_key :astronauts, :rockets
          assert_equal 1, @connection.foreign_keys("astronauts").size

          if current_adapter?(:SQLite3Adapter)
            assert_nothing_raised do
              @connection.add_foreign_key :astronauts, :rockets
            end
          else
            error = assert_raises do
              @connection.add_foreign_key :astronauts, :rockets
            end

            if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
              if ActiveRecord::Base.lease_connection.mariadb?
                assert_match(/Duplicate key on write or update/, error.message)
              elsif ActiveRecord::Base.lease_connection.database_version < "8.0"
                assert_match(/Can't write; duplicate key in table/, error.message)
              else
                assert_match(/Duplicate foreign key constraint name/, error.message)
              end
            else
              assert_match(/PG::DuplicateObject: ERROR:.*for relation "astronauts" already exists/, error.message)
            end

          end
        end

        def test_add_foreign_key_with_if_not_exists_set
          @connection.add_foreign_key :astronauts, :rockets
          assert_equal 1, @connection.foreign_keys("astronauts").size

          assert_nothing_raised do
            @connection.add_foreign_key :astronauts, :rockets, if_not_exists: true
          end
        end

        def test_add_foreign_key_preserves_existing_column_types
          assert_no_changes -> { column_for(:astronauts, :rocket_id).bigint? }, from: true do
            @connection.add_foreign_key :astronauts, :rockets
          end
        end

        private
          def column_for(table_name, column_name)
            @connection.columns(table_name).find { |column| column.name == column_name.to_s }
          end
      end

      class CompositeForeignKeyTest < ActiveRecord::TestCase
        include SchemaDumpingHelper

        setup do
          @connection = ActiveRecord::Base.lease_connection
          @connection.create_table :rockets, primary_key: [:tenant_id, :id], force: true do |t|
            t.integer :tenant_id
            t.integer :id
          end
          @connection.create_table :astronauts, force: true do |t|
            t.integer :rocket_id
            t.integer :rocket_tenant_id
          end
        end

        teardown do
          @connection.drop_table :astronauts, if_exists: true rescue nil
          @connection.drop_table :rockets, if_exists: true rescue nil
        end

        def test_add_composite_foreign_key_raises_without_options
          error = assert_raises(ActiveRecord::StatementInvalid) do
            @connection.add_foreign_key :astronauts, :rockets
          end

          if current_adapter?(:PostgreSQLAdapter)
            assert_match(/there is no unique constraint matching given keys for referenced table "rockets"/, error.message)
          elsif current_adapter?(:SQLite3Adapter)
            assert_match(/foreign key mismatch - "astronauts" referencing "rockets"/, error.message)
          else
            # MariaDB and different versions of MySQL generate different error messages.
            [
              /Foreign key constraint is incorrectly formed/i,
              /Failed to add the foreign key constraint/i,
              /Cannot add foreign key constraint/i
            ].any? { |message| error.message.match?(message) }
          end
        end

        def test_add_composite_foreign_key_infers_column
          @connection.add_foreign_key :astronauts, :rockets, primary_key: [:tenant_id, :id]

          foreign_keys = @connection.foreign_keys(:astronauts)
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal ["rocket_tenant_id", "rocket_id"], fk.column
        end

        def test_add_composite_foreign_key_raises_if_column_and_primary_key_sizes_mismatch
          assert_raises(ArgumentError, match: ":column must reference all the :primary_key columns") do
            @connection.add_foreign_key :astronauts, :rockets, column: :rocket_id, primary_key: [:tenant_id, :id]
          end
        end

        def test_foreign_key_exists
          @connection.add_foreign_key :astronauts, :rockets, primary_key: [:tenant_id, :id]

          assert @connection.foreign_key_exists?(:astronauts, :rockets)
          assert_not @connection.foreign_key_exists?(:astronauts, :stars)
        end

        def test_foreign_key_exists_by_options
          @connection.add_foreign_key :astronauts, :rockets, primary_key: [:tenant_id, :id]

          assert @connection.foreign_key_exists?(:astronauts, :rockets, primary_key: [:tenant_id, :id])
          assert @connection.foreign_key_exists?(:astronauts, :rockets, column: [:rocket_tenant_id, :rocket_id], primary_key: [:tenant_id, :id])

          assert_not @connection.foreign_key_exists?(:astronauts, :rockets, primary_key: [:id, :tenant_id])
          assert_not @connection.foreign_key_exists?(:astronauts, :rockets, primary_key: :id)
          assert_not @connection.foreign_key_exists?(:astronauts, :rockets, column: :rocket_id)
        end

        def test_remove_foreign_key
          @connection.add_foreign_key :astronauts, :rockets, primary_key: [:tenant_id, :id]
          assert_equal 1, @connection.foreign_keys(:astronauts).size

          @connection.remove_foreign_key :astronauts, :rockets
          assert_empty @connection.foreign_keys(:astronauts)
        end

        def test_schema_dumping
          @connection.add_foreign_key :astronauts, :rockets, primary_key: [:tenant_id, :id]

          output = dump_table_schema "astronauts"

          assert_match %r{\s+add_foreign_key "astronauts", "rockets", column: \["rocket_tenant_id", "rocket_id"\], primary_key: \["tenant_id", "id"\]$}, output
        end
      end
    end
  end
end
