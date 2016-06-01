require "cases/helper"

class Horse < ActiveRecord::Base
end

module ActiveRecord
  class InvertibleMigrationTest < ActiveRecord::TestCase
    class SilentMigration < ActiveRecord::Migration::Current
      def write(text = '')
        # sssshhhhh!!
      end
    end

    class InvertibleMigration < SilentMigration
      def change
        create_table("horses") do |t|
          t.column :content, :text
          t.column :remind_at, :datetime
        end
      end
    end

    class InvertibleRevertMigration < SilentMigration
      def change
        revert do
          create_table("horses") do |t|
            t.column :content, :text
            t.column :remind_at, :datetime
          end
        end
      end
    end

    class InvertibleByPartsMigration < SilentMigration
      attr_writer :test
      def change
        create_table("new_horses") do |t|
          t.column :breed, :string
        end
        reversible do |dir|
          @test.yield :both
          dir.up    { @test.yield :up }
          dir.down  { @test.yield :down }
        end
        revert do
          create_table("horses") do |t|
            t.column :content, :text
            t.column :remind_at, :datetime
          end
        end
      end
    end

    class NonInvertibleMigration < SilentMigration
      def change
        create_table("horses") do |t|
          t.column :content, :text
          t.column :remind_at, :datetime
        end
        remove_column "horses", :content
      end
    end

    class RemoveIndexMigration1 < SilentMigration
      def self.up
        create_table("horses") do |t|
          t.column :name, :string
          t.column :color, :string
          t.index [:name, :color]
        end
      end
    end

    class RemoveIndexMigration2 < SilentMigration
      def change
        change_table("horses") do |t|
          t.remove_index [:name, :color]
        end
      end
    end

    class ChangeColumnDefault1 < SilentMigration
      def change
        create_table("horses") do |t|
          t.column :name, :string, default: "Sekitoba"
        end
      end
    end

    class ChangeColumnDefault2 < SilentMigration
      def change
        change_column_default :horses, :name, from: "Sekitoba", to: "Diomed"
      end
    end

    class DisableExtension1 < SilentMigration
      def change
        enable_extension "hstore"
      end
    end

    class DisableExtension2 < SilentMigration
      def change
        disable_extension "hstore"
      end
    end

    class LegacyMigration < ActiveRecord::Migration::Current
      def self.up
        create_table("horses") do |t|
          t.column :content, :text
          t.column :remind_at, :datetime
        end
      end

      def self.down
        drop_table("horses")
      end
    end

    class RevertWholeMigration < SilentMigration
      def initialize(name = self.class.name, version = nil, migration)
        @migration = migration
        super(name, version)
      end

      def change
        revert @migration
      end
    end

    class NestedRevertWholeMigration < RevertWholeMigration
      def change
        revert { super }
      end
    end

    class RevertNamedIndexMigration1 < SilentMigration
      def change
        create_table("horses") do |t|
          t.column :content, :string
          t.column :remind_at, :datetime
        end
        add_index :horses, :content
      end
    end

    class RevertNamedIndexMigration2 < SilentMigration
      def change
        add_index :horses, :content, name: "horses_index_named"
      end
    end

    class RevertCustomForeignKeyTable < SilentMigration
      def change
        change_table(:horses) do |t|
          t.references :owner, foreign_key: { to_table: :developers }
        end
      end
    end

    setup do
      @verbose_was, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, false
    end

    teardown do
      %w[horses new_horses].each do |table|
        ActiveSupport::Deprecation.silence do
          if ActiveRecord::Base.connection.table_exists?(table)
            ActiveRecord::Base.connection.drop_table(table)
          end
        end
      end
      ActiveRecord::Migration.verbose = @verbose_was
    end

    def test_no_reverse
      migration = NonInvertibleMigration.new
      migration.migrate(:up)
      assert_raises(IrreversibleMigration) do
        migration.migrate(:down)
      end
    end

    def test_exception_on_removing_index_without_column_option
      index_definition = ["horses", [:name, :color]]
      migration1 = RemoveIndexMigration1.new
      migration1.migrate(:up)
      assert migration1.connection.index_exists?(*index_definition)

      migration2 = RemoveIndexMigration2.new
      migration2.migrate(:up)
      assert_not migration2.connection.index_exists?(*index_definition)

      migration2.migrate(:down)
      assert migration2.connection.index_exists?(*index_definition)
    end

    def test_migrate_up
      migration = InvertibleMigration.new
      migration.migrate(:up)
      ActiveSupport::Deprecation.silence { assert migration.connection.table_exists?("horses"), "horses should exist" }
    end

    def test_migrate_down
      migration = InvertibleMigration.new
      migration.migrate :up
      migration.migrate :down
      ActiveSupport::Deprecation.silence { assert !migration.connection.table_exists?("horses") }
    end

    def test_migrate_revert
      migration = InvertibleMigration.new
      revert = InvertibleRevertMigration.new
      migration.migrate :up
      revert.migrate :up
      ActiveSupport::Deprecation.silence { assert !migration.connection.table_exists?("horses") }
      revert.migrate :down
      ActiveSupport::Deprecation.silence { assert migration.connection.table_exists?("horses") }
      migration.migrate :down
      ActiveSupport::Deprecation.silence { assert !migration.connection.table_exists?("horses") }
    end

    def test_migrate_revert_by_part
      InvertibleMigration.new.migrate :up
      received = []
      migration = InvertibleByPartsMigration.new
      migration.test = ->(dir){
        ActiveSupport::Deprecation.silence do
          assert migration.connection.table_exists?("horses")
          assert migration.connection.table_exists?("new_horses")
        end
        received << dir
      }
      migration.migrate :up
      assert_equal [:both, :up], received
      ActiveSupport::Deprecation.silence do
        assert !migration.connection.table_exists?("horses")
        assert migration.connection.table_exists?("new_horses")
      end
      migration.migrate :down
      assert_equal [:both, :up, :both, :down], received
      ActiveSupport::Deprecation.silence do
        assert migration.connection.table_exists?("horses")
        assert !migration.connection.table_exists?("new_horses")
      end
    end

    def test_migrate_revert_whole_migration
      migration = InvertibleMigration.new
      [LegacyMigration, InvertibleMigration].each do |klass|
        revert = RevertWholeMigration.new(klass)
        migration.migrate :up
        revert.migrate :up
        ActiveSupport::Deprecation.silence { assert !migration.connection.table_exists?("horses") }
        revert.migrate :down
        ActiveSupport::Deprecation.silence { assert migration.connection.table_exists?("horses") }
        migration.migrate :down
        ActiveSupport::Deprecation.silence { assert !migration.connection.table_exists?("horses") }
      end
    end

    def test_migrate_nested_revert_whole_migration
      revert = NestedRevertWholeMigration.new(InvertibleRevertMigration)
      revert.migrate :down
      ActiveSupport::Deprecation.silence { assert revert.connection.table_exists?("horses") }
      revert.migrate :up
      ActiveSupport::Deprecation.silence { assert !revert.connection.table_exists?("horses") }
    end

    def test_migrate_revert_change_column_default
      migration1 = ChangeColumnDefault1.new
      migration1.migrate(:up)
      assert_equal "Sekitoba", Horse.new.name

      migration2 = ChangeColumnDefault2.new
      migration2.migrate(:up)
      Horse.reset_column_information
      assert_equal "Diomed", Horse.new.name

      migration2.migrate(:down)
      Horse.reset_column_information
      assert_equal "Sekitoba", Horse.new.name
    end

    if current_adapter?(:PostgreSQLAdapter)
      def test_migrate_enable_and_disable_extension
        migration1 = InvertibleMigration.new
        migration2 = DisableExtension1.new
        migration3 = DisableExtension2.new

        migration1.migrate(:up)
        migration2.migrate(:up)
        assert_equal true, Horse.connection.extension_enabled?('hstore')

        migration3.migrate(:up)
        assert_equal false, Horse.connection.extension_enabled?('hstore')

        migration3.migrate(:down)
        assert_equal true, Horse.connection.extension_enabled?('hstore')

        migration2.migrate(:down)
        assert_equal false, Horse.connection.extension_enabled?('hstore')
      end
    end

    def test_revert_order
      block = Proc.new{|t| t.string :name }
      recorder = ActiveRecord::Migration::CommandRecorder.new(ActiveRecord::Base.connection)
      recorder.instance_eval do
        create_table("apples", &block)
        revert do
          create_table("bananas", &block)
          revert do
            create_table("clementines")
            create_table("dates")
          end
          create_table("elderberries")
        end
        revert do
          create_table("figs")
          create_table("grapes")
        end
      end
      assert_equal [[:create_table, ["apples"], block], [:drop_table, ["elderberries"], nil],
                    [:create_table, ["clementines"], nil], [:create_table, ["dates"], nil],
                    [:drop_table, ["bananas"], block], [:drop_table, ["grapes"], nil],
                    [:drop_table, ["figs"], nil]], recorder.commands
    end

    def test_legacy_up
      LegacyMigration.migrate :up
      ActiveSupport::Deprecation.silence { assert ActiveRecord::Base.connection.table_exists?("horses"), "horses should exist" }
    end

    def test_legacy_down
      LegacyMigration.migrate :up
      LegacyMigration.migrate :down
      ActiveSupport::Deprecation.silence { assert !ActiveRecord::Base.connection.table_exists?("horses"), "horses should not exist" }
    end

    def test_up
      LegacyMigration.up
      ActiveSupport::Deprecation.silence { assert ActiveRecord::Base.connection.table_exists?("horses"), "horses should exist" }
    end

    def test_down
      LegacyMigration.up
      LegacyMigration.down
      ActiveSupport::Deprecation.silence { assert !ActiveRecord::Base.connection.table_exists?("horses"), "horses should not exist" }
    end

    def test_migrate_down_with_table_name_prefix
      ActiveRecord::Base.table_name_prefix = 'p_'
      ActiveRecord::Base.table_name_suffix = '_s'
      migration = InvertibleMigration.new
      migration.migrate(:up)
      assert_nothing_raised { migration.migrate(:down) }
      ActiveSupport::Deprecation.silence { assert !ActiveRecord::Base.connection.table_exists?("p_horses_s"), "p_horses_s should not exist" }
    ensure
      ActiveRecord::Base.table_name_prefix = ActiveRecord::Base.table_name_suffix = ''
    end

    def test_migrations_can_handle_foreign_keys_to_specific_tables
      migration = RevertCustomForeignKeyTable.new
      InvertibleMigration.migrate(:up)
      migration.migrate(:up)
      migration.migrate(:down)
    end

    # MySQL 5.7 and Oracle do not allow to create duplicate indexes on the same columns
    unless current_adapter?(:Mysql2Adapter, :OracleAdapter)
      def test_migrate_revert_add_index_with_name
        RevertNamedIndexMigration1.new.migrate(:up)
        RevertNamedIndexMigration2.new.migrate(:up)
        RevertNamedIndexMigration2.new.migrate(:down)

        connection = ActiveRecord::Base.connection
        assert connection.index_exists?(:horses, :content),
               "index on content should exist"
        assert !connection.index_exists?(:horses, :content, name: "horses_index_named"),
              "horses_index_named index should not exist"
      end
    end

  end
end
