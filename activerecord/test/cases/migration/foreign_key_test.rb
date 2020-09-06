# frozen_string_literal: true

require 'cases/helper'
require 'support/schema_dumping_helper'

if ActiveRecord::Base.connection.supports_foreign_keys?
  module ActiveRecord
    class Migration
      class ForeignKeyInCreateTest < ActiveRecord::TestCase
        def test_foreign_keys
          foreign_keys = ActiveRecord::Base.connection.foreign_keys('fk_test_has_fk')
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal 'fk_test_has_fk', fk.from_table
          assert_equal 'fk_test_has_pk', fk.to_table
          assert_equal 'fk_id', fk.column
          assert_equal 'pk_id', fk.primary_key
          assert_equal 'fk_name', fk.name unless current_adapter?(:SQLite3Adapter)
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
          @connection = ActiveRecord::Base.connection
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
          rocket = Rocket.create!(name: 'myrocket')
          rocket.astronauts << Astronaut.create!

          @connection.change_column_null Rocket.table_name, :name, false

          foreign_keys = @connection.foreign_keys(Astronaut.table_name)
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal 'myrocket', Rocket.first.name
          assert_equal Astronaut.table_name, fk.from_table
          assert_equal Rocket.table_name, fk.to_table
        end

        def test_rename_column_of_child_table
          rocket = Rocket.create!(name: 'myrocket')
          rocket.astronauts << Astronaut.create!

          @connection.rename_column Astronaut.table_name, :name, :astronaut_name

          foreign_keys = @connection.foreign_keys(Astronaut.table_name)
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal 'myrocket', Rocket.first.name
          assert_equal Astronaut.table_name, fk.from_table
          assert_equal Rocket.table_name, fk.to_table
        end

        def test_rename_reference_column_of_child_table
          if current_adapter?(:Mysql2Adapter) && !@connection.send(:supports_rename_index?)
            skip 'Cannot drop index, needed in a foreign key constraint'
          end

          rocket = Rocket.create!(name: 'myrocket')
          rocket.astronauts << Astronaut.create!

          @connection.rename_column Astronaut.table_name, :rocket_id, :new_rocket_id

          foreign_keys = @connection.foreign_keys(Astronaut.table_name)
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal 'myrocket', Rocket.first.name
          assert_equal Astronaut.table_name, fk.from_table
          assert_equal Rocket.table_name, fk.to_table
          assert_equal 'new_rocket_id', fk.options[:column]
        end

        def test_remove_reference_column_of_child_table
          rocket = Rocket.create!(name: 'myrocket')
          rocket.astronauts << Astronaut.create!

          @connection.remove_column Astronaut.table_name, :rocket_id

          assert_empty @connection.foreign_keys(Astronaut.table_name)
        end

        def test_remove_foreign_key_by_column
          rocket = Rocket.create!(name: 'myrocket')
          rocket.astronauts << Astronaut.create!

          @connection.remove_foreign_key Astronaut.table_name, column: :rocket_id

          assert_empty @connection.foreign_keys(Astronaut.table_name)
        end

        def test_remove_foreign_key_by_column_in_change_table
          rocket = Rocket.create!(name: 'myrocket')
          rocket.astronauts << Astronaut.create!

          @connection.change_table Astronaut.table_name do |t|
            t.remove_foreign_key column: :rocket_id
          end

          assert_empty @connection.foreign_keys(Astronaut.table_name)
        end
      end

      class ForeignKeyChangeColumnWithPrefixTest < ForeignKeyChangeColumnTest
        setup do
          ActiveRecord::Base.table_name_prefix = 'p_'
        end

        teardown do
          ActiveRecord::Base.table_name_prefix = nil
        end
      end

      class ForeignKeyChangeColumnWithSuffixTest < ForeignKeyChangeColumnTest
        setup do
          ActiveRecord::Base.table_name_suffix = '_s'
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
          @connection = ActiveRecord::Base.connection
          @connection.create_table 'rockets', force: true do |t|
            t.string :name
          end

          @connection.create_table 'astronauts', force: true do |t|
            t.string :name
            t.references :rocket
          end
        end

        teardown do
          @connection.drop_table 'astronauts', if_exists: true
          @connection.drop_table 'rockets', if_exists: true
        end

        def test_foreign_keys
          foreign_keys = @connection.foreign_keys('fk_test_has_fk')
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal 'fk_test_has_fk', fk.from_table
          assert_equal 'fk_test_has_pk', fk.to_table
          assert_equal 'fk_id', fk.column
          assert_equal 'pk_id', fk.primary_key
          assert_equal 'fk_name', fk.name unless current_adapter?(:SQLite3Adapter)
        end

        def test_add_foreign_key_inferes_column
          @connection.add_foreign_key :astronauts, :rockets

          foreign_keys = @connection.foreign_keys('astronauts')
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal 'astronauts', fk.from_table
          assert_equal 'rockets', fk.to_table
          assert_equal 'rocket_id', fk.column
          assert_equal 'id', fk.primary_key
          assert_equal 'fk_rails_78146ddd2e', fk.name unless current_adapter?(:SQLite3Adapter)
        end

        def test_add_foreign_key_with_column
          @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id'

          foreign_keys = @connection.foreign_keys('astronauts')
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal 'astronauts', fk.from_table
          assert_equal 'rockets', fk.to_table
          assert_equal 'rocket_id', fk.column
          assert_equal 'id', fk.primary_key
          assert_equal 'fk_rails_78146ddd2e', fk.name unless current_adapter?(:SQLite3Adapter)
        end

        def test_add_foreign_key_with_non_standard_primary_key
          @connection.create_table :space_shuttles, id: false, force: true do |t|
            t.bigint :pk, primary_key: true
          end

          @connection.add_foreign_key(:astronauts, :space_shuttles,
            column: 'rocket_id', primary_key: 'pk', name: 'custom_pk')

          foreign_keys = @connection.foreign_keys('astronauts')
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal 'astronauts', fk.from_table
          assert_equal 'space_shuttles', fk.to_table
          assert_equal 'pk', fk.primary_key
        ensure
          @connection.remove_foreign_key :astronauts, name: 'custom_pk', to_table: 'space_shuttles'
          @connection.drop_table :space_shuttles
        end

        def test_add_on_delete_restrict_foreign_key
          @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', on_delete: :restrict

          foreign_keys = @connection.foreign_keys('astronauts')
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          if current_adapter?(:Mysql2Adapter)
            # ON DELETE RESTRICT is the default on MySQL
            assert_nil fk.on_delete
          else
            assert_equal :restrict, fk.on_delete
          end
        end

        def test_add_on_delete_cascade_foreign_key
          @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', on_delete: :cascade

          foreign_keys = @connection.foreign_keys('astronauts')
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal :cascade, fk.on_delete
        end

        def test_add_on_delete_nullify_foreign_key
          @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', on_delete: :nullify

          foreign_keys = @connection.foreign_keys('astronauts')
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal :nullify, fk.on_delete
        end

        def test_on_update_and_on_delete_raises_with_invalid_values
          assert_raises ArgumentError do
            @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', on_delete: :invalid
          end

          assert_raises ArgumentError do
            @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', on_update: :invalid
          end
        end

        def test_add_foreign_key_with_on_update
          @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', on_update: :nullify

          foreign_keys = @connection.foreign_keys('astronauts')
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
          @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id'

          assert @connection.foreign_key_exists?(:astronauts, column: 'rocket_id')
          assert_not @connection.foreign_key_exists?(:astronauts, column: 'star_id')
        end

        def test_foreign_key_exists_by_name
          skip if current_adapter?(:SQLite3Adapter)

          @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', name: 'fancy_named_fk'

          assert @connection.foreign_key_exists?(:astronauts, name: 'fancy_named_fk')
          assert_not @connection.foreign_key_exists?(:astronauts, name: 'other_fancy_named_fk')
        end

        def test_foreign_key_exists_in_change_table
          @connection.change_table(:astronauts) do |t|
            t.foreign_key :rockets, column: 'rocket_id', name: 'fancy_named_fk'

            assert t.foreign_key_exists?(column: 'rocket_id')
            assert_not t.foreign_key_exists?(column: 'star_id')

            unless current_adapter?(:SQLite3Adapter)
              assert t.foreign_key_exists?(name: 'fancy_named_fk')
              assert_not t.foreign_key_exists?(name: 'other_fancy_named_fk')
            end
          end
        end

        def test_remove_foreign_key_inferes_column
          @connection.add_foreign_key :astronauts, :rockets

          assert_equal 1, @connection.foreign_keys('astronauts').size
          @connection.remove_foreign_key :astronauts, :rockets
          assert_equal [], @connection.foreign_keys('astronauts')
        end

        def test_remove_foreign_key_by_column
          @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id'

          assert_equal 1, @connection.foreign_keys('astronauts').size
          @connection.remove_foreign_key :astronauts, column: 'rocket_id'
          assert_equal [], @connection.foreign_keys('astronauts')
        end

        def test_remove_foreign_key_by_symbol_column
          @connection.add_foreign_key :astronauts, :rockets, column: :rocket_id

          assert_equal 1, @connection.foreign_keys('astronauts').size
          @connection.remove_foreign_key :astronauts, column: :rocket_id
          assert_equal [], @connection.foreign_keys('astronauts')
        end

        def test_remove_foreign_key_by_name
          skip if current_adapter?(:SQLite3Adapter)

          @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', name: 'fancy_named_fk'

          assert_equal 1, @connection.foreign_keys('astronauts').size
          @connection.remove_foreign_key :astronauts, name: 'fancy_named_fk'
          assert_equal [], @connection.foreign_keys('astronauts')
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

          assert_equal 2, @connection.foreign_keys('astronauts').size

          @connection.remove_foreign_key :astronauts, :rockets, column: 'myrocket_id'

          assert_equal [['astronauts', 'rockets', 'rocket_id']],
            @connection.foreign_keys('astronauts').map { |fk| [fk.from_table, fk.to_table, fk.column] }
        end

        if ActiveRecord::Base.connection.supports_validate_constraints?
          def test_add_invalid_foreign_key
            @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', validate: false

            foreign_keys = @connection.foreign_keys('astronauts')
            assert_equal 1, foreign_keys.size

            fk = foreign_keys.first
            assert_not_predicate fk, :validated?
          end

          def test_validate_foreign_key_infers_column
            @connection.add_foreign_key :astronauts, :rockets, validate: false
            assert_not_predicate @connection.foreign_keys('astronauts').first, :validated?

            @connection.validate_foreign_key :astronauts, :rockets
            assert_predicate @connection.foreign_keys('astronauts').first, :validated?
          end

          def test_validate_foreign_key_by_column
            @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', validate: false
            assert_not_predicate @connection.foreign_keys('astronauts').first, :validated?

            @connection.validate_foreign_key :astronauts, column: 'rocket_id'
            assert_predicate @connection.foreign_keys('astronauts').first, :validated?
          end

          def test_validate_foreign_key_by_symbol_column
            @connection.add_foreign_key :astronauts, :rockets, column: :rocket_id, validate: false
            assert_not_predicate @connection.foreign_keys('astronauts').first, :validated?

            @connection.validate_foreign_key :astronauts, column: :rocket_id
            assert_predicate @connection.foreign_keys('astronauts').first, :validated?
          end

          def test_validate_foreign_key_by_name
            @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', name: 'fancy_named_fk', validate: false
            assert_not_predicate @connection.foreign_keys('astronauts').first, :validated?

            @connection.validate_foreign_key :astronauts, name: 'fancy_named_fk'
            assert_predicate @connection.foreign_keys('astronauts').first, :validated?
          end

          def test_validate_foreign_non_existing_foreign_key_raises
            assert_raises ArgumentError do
              @connection.validate_foreign_key :astronauts, :rockets
            end
          end

          def test_validate_constraint_by_name
            @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', name: 'fancy_named_fk', validate: false

            @connection.validate_constraint :astronauts, 'fancy_named_fk'
            assert_predicate @connection.foreign_keys('astronauts').first, :validated?
          end
        else
          # Foreign key should still be created, but should not be invalid
          def test_add_invalid_foreign_key
            @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', validate: false

            foreign_keys = @connection.foreign_keys('astronauts')
            assert_equal 1, foreign_keys.size

            fk = foreign_keys.first
            assert_predicate fk, :validated?
          end
        end

        def test_schema_dumping
          @connection.add_foreign_key :astronauts, :rockets
          output = dump_table_schema 'astronauts'
          assert_match %r{\s+add_foreign_key "astronauts", "rockets"$}, output
        end

        def test_schema_dumping_with_options
          output = dump_table_schema 'fk_test_has_fk'
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

          output = dump_table_schema 'astronauts'
          assert_match %r{\s+add_foreign_key "astronauts", "rockets"$}, output

          ActiveRecord::SchemaDumper.fk_ignore_pattern = original_pattern
        end

        def test_schema_dumping_on_delete_and_on_update_options
          @connection.add_foreign_key :astronauts, :rockets, column: 'rocket_id', on_delete: :nullify, on_update: :cascade

          output = dump_table_schema 'astronauts'
          assert_match %r{\s+add_foreign_key "astronauts",.+on_update: :cascade,.+on_delete: :nullify$}, output
        end

        class CreateCitiesAndHousesMigration < ActiveRecord::Migration::Current
          def change
            create_table('cities') { |t| }

            create_table('houses') do |t|
              t.references :city
            end
            add_foreign_key :houses, :cities, column: 'city_id'

            # remove and re-add to test that schema is updated and not accidentally cached
            remove_foreign_key :houses, :cities
            add_foreign_key :houses, :cities, column: 'city_id', on_delete: :cascade
          end
        end

        def test_add_foreign_key_is_reversible
          migration = CreateCitiesAndHousesMigration.new
          silence_stream($stdout) { migration.migrate(:up) }
          assert_equal 1, @connection.foreign_keys('houses').size
        ensure
          silence_stream($stdout) { migration.migrate(:down) }
        end

        def test_foreign_key_constraint_is_not_cached_incorrectly
          migration = CreateCitiesAndHousesMigration.new
          silence_stream($stdout) { migration.migrate(:up) }
          output = dump_table_schema 'houses'
          assert_match %r{\s+add_foreign_key "houses",.+on_delete: :cascade$}, output
        ensure
          silence_stream($stdout) { migration.migrate(:down) }
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
          ActiveRecord::Base.table_name_prefix = 'p_'
          migration = CreateSchoolsAndClassesMigration.new
          silence_stream($stdout) { migration.migrate(:up) }
          assert_equal 1, @connection.foreign_keys('p_classes').size
        ensure
          silence_stream($stdout) { migration.migrate(:down) }
          ActiveRecord::Base.table_name_prefix = nil
        end

        def test_add_foreign_key_with_suffix
          ActiveRecord::Base.table_name_suffix = '_s'
          migration = CreateSchoolsAndClassesMigration.new
          silence_stream($stdout) { migration.migrate(:up) }
          assert_equal 1, @connection.foreign_keys('classes_s').size
        ensure
          silence_stream($stdout) { migration.migrate(:down) }
          ActiveRecord::Base.table_name_suffix = nil
        end
      end
    end
  end
end
