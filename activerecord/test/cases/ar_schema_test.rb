require "cases/helper"

if ActiveRecord::Base.connection.supports_migrations?

  class ActiveRecordSchemaTest < ActiveRecord::TestCase
    self.use_transactional_fixtures = false

    def setup
      @connection = ActiveRecord::Base.connection
    end

    def teardown
      @connection.drop_table :fruits rescue nil
    end

    def test_schema_define
      ActiveRecord::Schema.define(:version => 7) do
        create_table :fruits do |t|
          t.column :color, :string
          t.column :fruit_size, :string  # NOTE: "size" is reserved in Oracle
          t.column :texture, :string
          t.column :flavor, :string
        end
      end

      assert_nothing_raised { @connection.select_all "SELECT * FROM fruits" }
      assert_nothing_raised { @connection.select_all "SELECT * FROM schema_migrations" }
      assert_equal 7, ActiveRecord::Migrator::current_version
    end

    def test_schema_raises_an_error_for_invalid_column_type
      assert_raise NoMethodError do
        ActiveRecord::Schema.define(:version => 8) do
          create_table :vegetables do |t|
            t.unknown :color
          end
        end
      end
    end

    def test_schema_subclass
      Class.new(ActiveRecord::Schema).define(:version => 9) do
        create_table :fruits
      end
      assert_nothing_raised { @connection.select_all "SELECT * FROM fruits" }
    end
  end

  class ActiveRecordSchemaMigrationsTest < ActiveRecordSchemaTest
    def setup
      super
      ActiveRecord::SchemaMigration.delete_all
    end

    def test_migration_adds_row_to_migrations_table
      schema = ActiveRecord::Schema.new
      schema.migration(1001, "", "")
      schema.migration(1002, "123456789012345678901234567890ab", "add_magic_power_to_unicorns")

      migrations = ActiveRecord::SchemaMigration.all.to_a
      assert_equal 2, migrations.length

      assert_equal 1001, migrations[0].version
      assert_match %r{^2\d\d\d-}, migrations[0].migrated_at.to_s(:db)
      assert_equal "", migrations[0].fingerprint
      assert_equal "", migrations[0].name

      assert_equal 1002, migrations[1].version
      assert_match %r{^2\d\d\d-}, migrations[1].migrated_at.to_s(:db)
      assert_equal "123456789012345678901234567890ab", migrations[1].fingerprint
      assert_equal "add_magic_power_to_unicorns", migrations[1].name
    end

    def test_define_clears_schema_migrations
      assert_nothing_raised do
        ActiveRecord::Schema.define do
          migrations do
            migration(123001, "", "")
          end
        end
        ActiveRecord::Schema.define do
          migrations do
            migration(123001, "", "")
          end
        end
      end
    end

    def test_define_raises_if_both_version_and_explicit_migrations
      assert_raise(ArgumentError) do
        ActiveRecord::Schema.define(version: 123001) do
          migrations do
            migration(123001, "", "")
          end
        end
      end
    end
  end

end
