require 'cases/helper'
require 'support/ddl_helper'
require 'support/schema_dumping_helper'

if ActiveRecord::Base.connection.supports_foreign_keys?
module ActiveRecord
  class Migration
    class ForeignKeyTest < ActiveRecord::TestCase
      include DdlHelper
      include SchemaDumpingHelper
      include ActiveSupport::Testing::Stream

      class Rocket < ActiveRecord::Base
      end

      class Astronaut < ActiveRecord::Base
      end

      setup do
        @connection = ActiveRecord::Base.connection
        @connection.create_table "rockets", force: true do |t|
          t.string :name
        end

        @connection.create_table "astronauts", force: true do |t|
          t.string :name
          t.references :rocket
        end
      end

      teardown do
        if defined?(@connection)
          @connection.drop_table "astronauts", if_exists: true
          @connection.drop_table "rockets", if_exists: true
        end
      end

      def test_foreign_keys
        foreign_keys = @connection.foreign_keys("fk_test_has_fk")
        assert_equal 1, foreign_keys.size

        fk = foreign_keys.first
        assert_equal "fk_test_has_fk", fk.from_table
        assert_equal "fk_test_has_pk", fk.to_table
        assert_equal "fk_id", fk.column
        assert_equal "pk_id", fk.primary_key
        assert_equal "fk_name", fk.name
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
        assert_equal("fk_rails_78146ddd2e", fk.name)
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
        assert_equal("fk_rails_78146ddd2e", fk.name)
      end

      def test_add_foreign_key_with_non_standard_primary_key
        with_example_table @connection, "space_shuttles", "pk integer PRIMARY KEY" do
          @connection.add_foreign_key(:astronauts, :space_shuttles,
                                      column: "rocket_id", primary_key: "pk", name: "custom_pk")

          foreign_keys = @connection.foreign_keys("astronauts")
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal "astronauts", fk.from_table
          assert_equal "space_shuttles", fk.to_table
          assert_equal "pk", fk.primary_key

          @connection.remove_foreign_key :astronauts, name: "custom_pk"
        end
      end

      def test_add_on_delete_restrict_foreign_key
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", on_delete: :restrict

        foreign_keys = @connection.foreign_keys("astronauts")
        assert_equal 1, foreign_keys.size

        fk = foreign_keys.first
        if current_adapter?(:Mysql2Adapter)
          # ON DELETE RESTRICT is the default on MySQL
          assert_equal nil, fk.on_delete
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

      def test_foreign_key_exists
        @connection.add_foreign_key :astronauts, :rockets

        assert @connection.foreign_key_exists?(:astronauts, :rockets)
        assert_not @connection.foreign_key_exists?(:astronauts, :stars)
      end

      def test_foreign_key_exists_by_column
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id"

        assert @connection.foreign_key_exists?(:astronauts, column: "rocket_id")
        assert_not @connection.foreign_key_exists?(:astronauts, column: "star_id")
      end

      def test_foreign_key_exists_by_name
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", name: "fancy_named_fk"

        assert @connection.foreign_key_exists?(:astronauts, name: "fancy_named_fk")
        assert_not @connection.foreign_key_exists?(:astronauts, name: "other_fancy_named_fk")
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
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", name: "fancy_named_fk"

        assert_equal 1, @connection.foreign_keys("astronauts").size
        @connection.remove_foreign_key :astronauts, name: "fancy_named_fk"
        assert_equal [], @connection.foreign_keys("astronauts")
      end

      def test_remove_foreign_non_existing_foreign_key_raises
        assert_raises ArgumentError do
          @connection.remove_foreign_key :astronauts, :rockets
        end
      end

      def test_schema_dumping
        @connection.add_foreign_key :astronauts, :rockets
        output = dump_table_schema "astronauts"
        assert_match %r{\s+add_foreign_key "astronauts", "rockets"$}, output
      end

      def test_schema_dumping_with_options
        output = dump_table_schema "fk_test_has_fk"
        assert_match %r{\s+add_foreign_key "fk_test_has_fk", "fk_test_has_pk", column: "fk_id", primary_key: "pk_id", name: "fk_name"$}, output
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
            t.column :city_id, :integer
          end
          add_foreign_key :houses, :cities, column: "city_id"

          # remove and re-add to test that schema is updated and not accidently cached
          remove_foreign_key :houses, :cities
          add_foreign_key :houses, :cities, column: "city_id", on_delete: :cascade
        end
      end

      def test_add_foreign_key_is_reversible
        migration = CreateCitiesAndHousesMigration.new
        silence_stream($stdout) { migration.migrate(:up) }
        assert_equal 1, @connection.foreign_keys("houses").size
      ensure
        silence_stream($stdout) { migration.migrate(:down) }
      end

      def test_foreign_key_constraint_is_not_cached_incorrectly
        migration = CreateCitiesAndHousesMigration.new
        silence_stream($stdout) { migration.migrate(:up) }
        output = dump_table_schema "houses"
        assert_match %r{\s+add_foreign_key "houses",.+on_delete: :cascade$}, output
      ensure
        silence_stream($stdout) { migration.migrate(:down) }
      end

      class CreateSchoolsAndClassesMigration < ActiveRecord::Migration::Current
        def change
          create_table(:schools)

          create_table(:classes) do |t|
            t.column :school_id, :integer
          end
          add_foreign_key :classes, :schools
        end
      end

      def test_add_foreign_key_with_prefix
        ActiveRecord::Base.table_name_prefix = 'p_'
        migration = CreateSchoolsAndClassesMigration.new
        silence_stream($stdout) { migration.migrate(:up) }
        assert_equal 1, @connection.foreign_keys("p_classes").size
      ensure
        silence_stream($stdout) { migration.migrate(:down) }
        ActiveRecord::Base.table_name_prefix = nil
      end

      def test_add_foreign_key_with_suffix
        ActiveRecord::Base.table_name_suffix = '_s'
        migration = CreateSchoolsAndClassesMigration.new
        silence_stream($stdout) { migration.migrate(:up) }
        assert_equal 1, @connection.foreign_keys("classes_s").size
      ensure
        silence_stream($stdout) { migration.migrate(:down) }
        ActiveRecord::Base.table_name_suffix = nil
      end

    end
  end
end
else
module ActiveRecord
  class Migration
    class NoForeignKeySupportTest < ActiveRecord::TestCase
      setup do
        @connection = ActiveRecord::Base.connection
      end

      def test_add_foreign_key_should_be_noop
        @connection.add_foreign_key :clubs, :categories
      end

      def test_remove_foreign_key_should_be_noop
        @connection.remove_foreign_key :clubs, :categories
      end

      def test_foreign_keys_should_raise_not_implemented
        assert_raises NotImplementedError do
          @connection.foreign_keys("clubs")
        end
      end
    end
  end
end
end
