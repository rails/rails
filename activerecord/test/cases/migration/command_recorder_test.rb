# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class Migration
    class CommandRecorderTest < ActiveRecord::TestCase
      def setup
        connection = ActiveRecord::Base.lease_connection
        @recorder  = CommandRecorder.new(connection)
      end

      def test_respond_to_delegates
        recorder = CommandRecorder.new(Class.new {
          def america; end
        }.new)
        assert_respond_to recorder, :america
      end

      def test_send_calls_super
        assert_raises(NoMethodError) do
          @recorder.send(:non_existing_method, :horses)
        end
      end

      def test_send_delegates_to_record
        recorder = CommandRecorder.new(Class.new {
          def create_table(name); end
        }.new)
        assert_respond_to recorder, :create_table
        recorder.send(:create_table, :horses)
        assert_equal [[:create_table, [:horses], {}, nil]], recorder.commands
      end

      def test_unknown_commands_delegate
        recorder = Class.new do
          def foo(kw:)
            kw
          end
        end
        recorder = CommandRecorder.new(recorder.new)
        assert_equal "bar", recorder.foo(kw: "bar")
      end

      def test_irreversible_commands_raise_exception
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert { @recorder.execute "some sql" }
        end
      end

      def test_record
        @recorder.create_table :system_settings
        assert_equal 1, @recorder.commands.length
      end

      def test_inverted_commands_are_reversed
        @recorder.revert do
          @recorder.create_table :hello
          @recorder.create_table :world
        end
        tables = @recorder.commands.map { |_cmd, args, _kwargs, _block| args }
        assert_equal [[:world], [:hello]], tables
      end

      def test_revert_order
        block = Proc.new { |t| t.string :name }
        @recorder.instance_eval do
          create_table("apples", &block)
          revert do
            create_table("bananas", &block)
            revert do
              create_table("clementines", &block)
              create_table("dates")
            end
            create_table("elderberries")
          end
          revert do
            create_table("figs", &block)
            create_table("grapes")
          end
        end
        assert_equal [[:create_table, ["apples"], {}, block], [:drop_table, ["elderberries"], {}, nil],
                      [:create_table, ["clementines"], {}, block], [:create_table, ["dates"], {}, nil],
                      [:drop_table, ["bananas"], {}, block], [:drop_table, ["grapes"], {}, nil],
                      [:drop_table, ["figs"], {}, block]], @recorder.commands
      end

      def test_invert_change_table
        @recorder.revert do
          @recorder.change_table :fruits do |t|
            t.string :name
            t.rename :kind, :cultivar
          end
        end

        assert_equal [
          [:rename_column, [:fruits, :cultivar, :kind], {}],
          [:remove_column, [:fruits, :name, :string], {}, nil],
        ], @recorder.commands

        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.change_table :fruits do |t|
              t.remove :kind
            end
          end
        end
      end

      if ActiveRecord::Base.lease_connection.supports_bulk_alter?
        def test_bulk_invert_change_table
          block = Proc.new do |t|
            t.string :name
            t.rename :kind, :cultivar
          end

          @recorder.revert do
            @recorder.change_table :fruits, bulk: true, &block
          end

          @recorder.revert do
            @recorder.revert do
              @recorder.change_table :fruits, bulk: true, &block
            end
          end

          assert_equal [
            [:change_table, [:fruits], {}],
            [:change_table, [:fruits], {}]
          ], @recorder.commands.map { |command| command[0...-1] }
        end
      end

      def test_invert_create_table
        @recorder.revert do
          @recorder.create_table :system_settings
        end
        drop_table = @recorder.commands.first
        assert_equal [:drop_table, [:system_settings], {}, nil], drop_table
      end

      def test_invert_create_table_with_if_not_exists
        @recorder.revert do
          @recorder.create_table :system_settings, if_not_exists: true
        end
        drop_table = @recorder.commands.first
        assert_equal [:drop_table, [:system_settings], {}, nil], drop_table
      end

      def test_invert_create_table_with_options_and_block
        block = Proc.new { }
        @recorder.revert do
          @recorder.create_table(:people_reminders, id: false, &block)
        end
        assert_equal [:drop_table, [:people_reminders], { id: false }, block], @recorder.commands.first
      end

      def test_invert_drop_table
        block = Proc.new { }
        @recorder.revert do
          @recorder.drop_table(:people_reminders, id: false, &block)
        end
        assert_equal [:create_table, [:people_reminders], { id: false }, block], @recorder.commands.first
      end

      def test_invert_drop_table_with_if_exists
        block = Proc.new { }
        @recorder.revert do
          @recorder.drop_table(:people_reminders, id: false, if_exists: true, &block)
        end
        assert_equal [:create_table, [:people_reminders], { id: false }, block], @recorder.commands.first
      end

      def test_invert_drop_table_without_a_block_nor_option
        assert_raises(ActiveRecord::IrreversibleMigration, match: "To avoid mistakes, drop_table is only reversible if given options or a block (can be empty).") do
          @recorder.revert do
            @recorder.drop_table(:people_reminders)
          end
        end
      end

      def test_invert_drop_table_with_multiple_tables
        assert_raises(ActiveRecord::IrreversibleMigration, match: "To avoid mistakes, drop_table is only reversible if given a single table name.") do
          @recorder.revert do
            @recorder.drop_table(:musics, :artists)
          end
        end
      end

      def test_invert_drop_table_with_multiple_tables_and_options
        assert_raises(ActiveRecord::IrreversibleMigration, match: "To avoid mistakes, drop_table is only reversible if given a single table name.") do
          @recorder.revert do
            @recorder.drop_table(:musics, :artists, id: false)
          end
        end
      end

      def test_invert_drop_table_with_multiple_tables_and_block
        block = Proc.new { }

        assert_raises(ActiveRecord::IrreversibleMigration, match: "To avoid mistakes, drop_table is only reversible if given a single table name.") do
          @recorder.revert do
            @recorder.drop_table(:musics, :artists, &block)
          end
        end
      end

      def test_invert_create_join_table
        @recorder.revert do
          @recorder.create_join_table(:musics, :artists)
        end
        assert_equal [:drop_join_table, [:musics, :artists], {}, nil], @recorder.commands.first
      end

      def test_invert_create_join_table_with_table_name
        @recorder.revert do
          @recorder.create_join_table(:musics, :artists, table_name: :catalog)
        end
        assert_equal [:drop_join_table, [:musics, :artists], { table_name: :catalog }, nil], @recorder.commands.first
      end

      def test_invert_drop_join_table
        block = Proc.new { }
        @recorder.revert do
          @recorder.drop_join_table(:musics, :artists, table_name: :catalog, &block)
        end
        assert_equal [:create_join_table, [:musics, :artists], { table_name: :catalog }, block], @recorder.commands.first
      end

      def test_invert_rename_table
        @recorder.revert do
          @recorder.rename_table(:old, :new)
        end
        assert_equal [:rename_table, [:new, :old], {}], @recorder.commands.first
      end

      def test_invert_add_column
        @recorder.revert do
          @recorder.add_column(:table, :column, :type)
        end
        assert_equal [:remove_column, [:table, :column, :type], {}, nil], @recorder.commands.first
      end

      def test_invert_add_column_if_not_exists
        @recorder.revert do
          @recorder.add_column(:table, :column, :type, if_not_exists: true)
        end
        assert_equal [:remove_column, [:table, :column, :type], { if_exists: true }, nil], @recorder.commands.first
      end

      def test_invert_change_column
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.change_column(:table, :column, :type)
          end
        end
      end

      def test_invert_change_column_default
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.change_column_default(:table, :column, "default_value")
          end
        end
      end

      def test_invert_change_column_default_with_from_and_to
        @recorder.revert do
          @recorder.change_column_default(:table, :column, from: "old_value", to: "new_value")
        end
        assert_equal [:change_column_default, [:table, :column], { from: "new_value", to: "old_value" }], @recorder.commands.first
      end

      def test_invert_change_column_default_with_from_and_to_with_boolean
        @recorder.revert do
          @recorder.change_column_default(:table, :column, from: true, to: false)
        end
        assert_equal [:change_column_default, [:table, :column], { from: false, to: true }], @recorder.commands.first
      end

      if ActiveRecord::Base.lease_connection.supports_comments?
        def test_invert_change_column_comment
          assert_raises(ActiveRecord::IrreversibleMigration) do
            @recorder.revert do
              @recorder.change_column_comment(:table, :column, "comment")
            end
          end
        end

        def test_invert_change_column_comment_with_from_and_to
          @recorder.revert do
            @recorder.change_column_comment(:table, :column, from: "old_value", to: "new_value")
          end
          assert_equal [:change_column_comment, [:table, :column], { from: "new_value", to: "old_value" }], @recorder.commands.first
        end

        def test_invert_change_column_comment_with_from_and_to_with_nil
          @recorder.revert do
            @recorder.change_column_comment(:table, :column, from: nil, to: "new_value")
          end
          assert_equal [:change_column_comment, [:table, :column], { from: "new_value", to: nil }], @recorder.commands.first
        end

        def test_invert_change_table_comment
          assert_raises(ActiveRecord::IrreversibleMigration) do
            @recorder.revert do
              @recorder.change_column_comment(:table, :column, "comment")
            end
          end
        end

        def test_invert_change_table_comment_with_from_and_to
          @recorder.revert do
            @recorder.change_table_comment(:table, from: "old_value", to: "new_value")
          end
          assert_equal [:change_table_comment, [:table], { from: "new_value", to: "old_value" }], @recorder.commands.first
        end

        def test_invert_change_table_comment_with_from_and_to_with_nil
          @recorder.revert do
            @recorder.change_table_comment(:table, from: nil, to: "new_value")
          end
          assert_equal [:change_table_comment, [:table], { from: "new_value", to: nil }], @recorder.commands.first
        end
      end

      def test_invert_change_column_null
        @recorder.revert do
          @recorder.change_column_null(:table, :column, true)
        end
        assert_equal [:change_column_null, [:table, :column, false, nil], {}], @recorder.commands.first
      end

      def test_invert_remove_column
        @recorder.revert do
          @recorder.remove_column(:table, :column, :type)
        end
        assert_equal [:add_column, [:table, :column, :type], {}, nil], @recorder.commands.first
      end

      def test_invert_remove_column_if_exists
        @recorder.revert do
          @recorder.remove_column(:table, :column, :string, if_exists: true)
        end
        assert_equal [:add_column, [:table, :column, :string], { if_not_exists: true }, nil], @recorder.commands.first
      end

      def test_invert_remove_column_without_type
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.remove_column(:table, :column)
          end
        end
      end

      def test_invert_remove_column_with_options_but_no_type
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.remove_column(:table, :column, null: false)
          end
        end
      end

      def test_invert_rename_column
        @recorder.revert do
          @recorder.rename_column(:table, :old, :new)
        end
        assert_equal [:rename_column, [:table, :new, :old], {}], @recorder.commands.first
      end

      def test_invert_rename_column_with_options
        @recorder.revert do
          @recorder.rename_column(:table, :old, :new, algorithm: :inplace, lock: :none)
        end
        assert_equal [:rename_column, [:table, :new, :old], { algorithm: :inplace, lock: :none }], @recorder.commands.first
      end

      def test_invert_add_index
        @recorder.revert do
          @recorder.add_index(:table, [:one, :two])
        end
        assert_equal [:remove_index, [:table, [:one, :two]], {}, nil], @recorder.commands.first
      end

      def test_invert_add_index_with_name
        @recorder.revert do
          @recorder.add_index(:table, [:one, :two], name: "new_index")
        end
        assert_equal [:remove_index, [:table, [:one, :two]], { name: "new_index" }, nil], @recorder.commands.first
      end

      def test_invert_add_index_with_algorithm_option
        @recorder.revert do
          @recorder.add_index(:table, :one, algorithm: :concurrently)
        end
        assert_equal [:remove_index, [:table, :one], { algorithm: :concurrently }, nil], @recorder.commands.first
      end

      def test_invert_add_index_if_not_exists
        @recorder.revert do
          @recorder.add_index(:table, :one, if_not_exists: true)
        end
        assert_equal [:remove_index, [:table, :one], { if_exists: true }, nil], @recorder.commands.first
      end

      if ActiveRecord::Base.lease_connection.supports_disabling_indexes?
        def test_invert_add_index_with_disabled_option
          @recorder.revert do
            @recorder.add_index(:table, :one, enabled: false)
          end
          assert_equal [:remove_index, [:table, :one], { enabled: false }, nil], @recorder.commands.first
        end

        def test_invert_remove_index_with_disabled_option
          @recorder.revert do
            @recorder.remove_index(:table, :one, enabled: false)
          end
          assert_equal [:add_index, [:table, :one], { enabled: false }], @recorder.commands.first
        end

        def test_invert_disable_index
          @recorder.revert do
            @recorder.disable_index(:table, :disabled_index)
          end
          assert_equal [:enable_index, [:table, :disabled_index], {}], @recorder.commands.first
        end

        def test_invert_enable_index
          @recorder.revert do
            @recorder.enable_index(:table, :enabled_index)
          end
          assert_equal [:disable_index, [:table, :enabled_index], {}], @recorder.commands.first
        end
      end

      def test_invert_remove_index
        @recorder.revert do
          @recorder.remove_index(:table, :one)
        end
        assert_equal [:add_index, [:table, :one], {}], @recorder.commands.first
      end

      def test_invert_remove_index_with_positional_column
        @recorder.revert do
          @recorder.remove_index(:table, [:one, :two], options: true)
        end
        assert_equal [:add_index, [:table, [:one, :two]], { options: true }], @recorder.commands.first
      end

      def test_invert_remove_index_with_column
        @recorder.revert do
          @recorder.remove_index(:table, column: [:one, :two], options: true)
        end
        assert_equal [:add_index, [:table, [:one, :two]], { options: true }], @recorder.commands.first
      end

      def test_invert_remove_index_with_name
        @recorder.revert do
          @recorder.remove_index(:table, column: [:one, :two], name: "new_index")
        end
        assert_equal [:add_index, [:table, [:one, :two]], { name: "new_index" }], @recorder.commands.first
      end

      def test_invert_remove_index_with_no_special_options
        @recorder.revert do
          @recorder.remove_index(:table, column: [:one, :two])
        end
        assert_equal [:add_index, [:table, [:one, :two]], {}], @recorder.commands.first
      end

      def test_invert_remove_index_if_exists
        @recorder.revert do
          @recorder.remove_index(:table, column: [:one, :two], if_exists: true)
        end
        assert_equal [:add_index, [:table, [:one, :two]], { if_not_exists: true }], @recorder.commands.first
      end

      def test_invert_remove_index_with_no_column
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.remove_index(:table, name: "new_index")
          end
        end
      end

      def test_invert_rename_index
        @recorder.revert do
          @recorder.rename_index(:table, :old, :new)
        end
        assert_equal [:rename_index, [:table, :new, :old], {}], @recorder.commands.first
      end

      def test_invert_add_timestamps
        @recorder.revert do
          @recorder.add_timestamps(:table)
        end
        assert_equal [:remove_timestamps, [:table], {}, nil], @recorder.commands.first
      end

      def test_invert_remove_timestamps
        @recorder.revert do
          @recorder.remove_timestamps(:table, null: true)
        end
        assert_equal [:add_timestamps, [:table], { null: true }, nil], @recorder.commands.first
      end

      def test_invert_add_reference
        @recorder.revert do
          @recorder.add_reference(:table, :taggable, polymorphic: true)
        end
        assert_equal [:remove_reference, [:table, :taggable], { polymorphic: true }, nil], @recorder.commands.first
      end

      def test_invert_add_belongs_to_alias
        @recorder.revert do
          @recorder.add_belongs_to(:table, :user)
        end
        assert_equal [:remove_reference, [:table, :user], {}, nil], @recorder.commands.first
      end

      def test_invert_remove_reference
        @recorder.revert do
          @recorder.remove_reference(:table, :taggable, polymorphic: true)
        end
        assert_equal [:add_reference, [:table, :taggable], { polymorphic: true }, nil], @recorder.commands.first
      end

      def test_invert_remove_reference_with_index_and_foreign_key
        @recorder.revert do
          @recorder.remove_reference(:table, :taggable, index: true, foreign_key: true)
        end
        assert_equal [:add_reference, [:table, :taggable], { index: true, foreign_key: true }, nil], @recorder.commands.first
      end

      def test_invert_remove_belongs_to_alias
        @recorder.revert do
          @recorder.remove_belongs_to(:table, :user)
        end
        assert_equal [:add_reference, [:table, :user], {}, nil], @recorder.commands.first
      end

      def test_invert_add_reference_if_not_exists
        @recorder.revert do
          @recorder.add_reference(:table, :taggable, polymorphic: true, if_not_exists: true)
        end
        assert_equal [:remove_reference, [:table, :taggable], { polymorphic: true, if_exists: true }, nil], @recorder.commands.first
      end

      def test_invert_remove_reference_if_exists
        @recorder.revert do
          @recorder.remove_reference(:table, :taggable, polymorphic: true, if_exists: true)
        end
        assert_equal [:add_reference, [:table, :taggable], { polymorphic: true, if_not_exists: true }, nil], @recorder.commands.first
      end

      def test_invert_enable_extension
        @recorder.revert do
          @recorder.enable_extension("uuid-ossp")
        end
        assert_equal [:disable_extension, ["uuid-ossp"], {}, nil], @recorder.commands.first
      end

      def test_invert_disable_extension
        @recorder.revert do
          @recorder.disable_extension("uuid-ossp")
        end
        assert_equal [:enable_extension, ["uuid-ossp"], {}, nil], @recorder.commands.first
      end

      def test_invert_create_schema
        @recorder.revert do
          @recorder.create_schema("myschema")
        end
        assert_equal [:drop_schema, ["myschema"], {}, nil], @recorder.commands.first
      end

      def test_invert_drop_schema
        @recorder.revert do
          @recorder.drop_schema("myschema")
        end
        assert_equal [:create_schema, ["myschema"], {}, nil], @recorder.commands.first
      end

      def test_invert_add_foreign_key
        @recorder.revert do
          @recorder.add_foreign_key(:dogs, :people)
        end
        assert_equal [:remove_foreign_key, [:dogs, :people], {}, nil], @recorder.commands.first
      end

      def test_invert_remove_foreign_key
        @recorder.revert do
          @recorder.remove_foreign_key(:dogs, :people)
        end
        assert_equal [:add_foreign_key, [:dogs, :people], {}], @recorder.commands.first
      end

      def test_invert_add_foreign_key_with_column
        @recorder.revert do
          @recorder.add_foreign_key(:dogs, :people, column: "owner_id")
        end
        assert_equal [:remove_foreign_key, [:dogs, :people], { column: "owner_id" }, nil], @recorder.commands.first
      end

      def test_invert_add_foreign_key_if_not_exists
        @recorder.revert do
          @recorder.add_foreign_key(:dogs, :people, if_not_exists: true)
        end
        assert_equal [:remove_foreign_key, [:dogs, :people], { if_exists: true }, nil], @recorder.commands.first
      end

      def test_invert_remove_foreign_key_with_column
        @recorder.revert do
          @recorder.remove_foreign_key(:dogs, :people, column: "owner_id")
        end
        assert_equal [:add_foreign_key, [:dogs, :people], { column: "owner_id" }], @recorder.commands.first
      end

      def test_invert_remove_foreign_key_if_exists
        @recorder.revert do
          @recorder.remove_foreign_key(:dogs, :people, if_exists: true)
        end
        assert_equal [:add_foreign_key, [:dogs, :people], { if_not_exists: true }], @recorder.commands.first
      end

      def test_invert_add_foreign_key_with_column_and_name
        @recorder.revert do
          @recorder.add_foreign_key(:dogs, :people, column: "owner_id", name: "fk")
        end
        assert_equal [:remove_foreign_key, [:dogs, :people], { column: "owner_id", name: "fk" }, nil], @recorder.commands.first
      end

      def test_invert_remove_foreign_key_with_column_and_name
        @recorder.revert do
          @recorder.remove_foreign_key(:dogs, :people, column: "owner_id", name: "fk")
        end
        assert_equal [:add_foreign_key, [:dogs, :people], { column: "owner_id", name: "fk" }], @recorder.commands.first
      end

      def test_invert_remove_foreign_key_with_primary_key
        @recorder.revert do
          @recorder.remove_foreign_key(:dogs, :people, primary_key: "person_id")
        end
        assert_equal [:add_foreign_key, [:dogs, :people], { primary_key: "person_id" }], @recorder.commands.first
      end

      def test_invert_remove_foreign_key_with_primary_key_and_to_table_in_options
        @recorder.revert do
          @recorder.remove_foreign_key(:dogs, to_table: :people, primary_key: "uuid")
        end
        assert_equal [:add_foreign_key, [:dogs, :people], { primary_key: "uuid" }], @recorder.commands.first
      end

      def test_invert_remove_foreign_key_with_on_delete_on_update
        @recorder.revert do
          @recorder.remove_foreign_key(:dogs, :people, on_delete: :nullify, on_update: :cascade)
        end
        assert_equal [:add_foreign_key, [:dogs, :people], { on_delete: :nullify, on_update: :cascade }], @recorder.commands.first
      end

      def test_invert_remove_foreign_key_with_to_table_in_options
        @recorder.revert do
          @recorder.remove_foreign_key(:dogs, to_table: :people)
        end
        assert_equal [:add_foreign_key, [:dogs, :people], {}], @recorder.commands.first

        @recorder.revert do
          @recorder.remove_foreign_key(:dogs, to_table: :people, column: :owner_id)
        end
        assert_equal [:add_foreign_key, [:dogs, :people], { column: :owner_id }], @recorder.commands.last
      end

      def test_invert_remove_foreign_key_is_irreversible_without_to_table
        assert_raises ActiveRecord::IrreversibleMigration do
          @recorder.revert do
            @recorder.remove_foreign_key(:dogs, column: "owner_id")
          end
        end

        assert_raises ActiveRecord::IrreversibleMigration do
          @recorder.revert do
            @recorder.remove_foreign_key(:dogs, name: "fk")
          end
        end

        assert_raises ActiveRecord::IrreversibleMigration do
          @recorder.revert do
            @recorder.remove_foreign_key(:dogs)
          end
        end
      end

      def test_invert_transaction_with_irreversible_inside_is_irreversible
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.transaction do
              @recorder.execute "some sql"
            end
          end
        end
      end

      def test_invert_add_check_constraint
        @recorder.revert do
          @recorder.add_check_constraint(:dogs, "speed > 0", name: "speed_check")
        end
        assert_equal [:remove_check_constraint, [:dogs, "speed > 0"], { name: "speed_check" }, nil], @recorder.commands.first
      end

      def test_invert_add_check_constraint_if_not_exists
        @recorder.revert do
          @recorder.add_check_constraint(:dogs, "speed > 0", name: "speed_check", if_not_exists: true)
        end
        assert_equal [:remove_check_constraint, [:dogs, "speed > 0"], { name: "speed_check", if_exists: true }, nil], @recorder.commands.first
      end

      def test_invert_remove_check_constraint
        @recorder.revert do
          @recorder.remove_check_constraint(:dogs, "speed > 0", name: "speed_check")
        end
        assert_equal [:add_check_constraint, [:dogs, "speed > 0"], { name: "speed_check" }, nil], @recorder.commands.first
      end

      def test_invert_remove_check_constraint_without_expression
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.remove_check_constraint(:dogs)
          end
        end
      end

      def test_invert_remove_check_constraint_if_exists
        @recorder.revert do
          @recorder.remove_check_constraint(:dogs, "speed > 0", name: "speed_check", if_exists: true)
        end
        assert_equal [:add_check_constraint, [:dogs, "speed > 0"], { name: "speed_check", if_not_exists: true }, nil], @recorder.commands.first
      end

      def test_invert_add_unique_constraint_constraint_with_using_index
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.add_unique_constraint(:dogs, using_index: "unique_index")
          end
        end
      end

      def test_invert_remove_unique_constraint_constraint
        @recorder.revert do
          @recorder.remove_unique_constraint(:dogs, ["speed"], deferrable: :deferred, name: "uniq_speed")
        end
        assert_equal [:add_unique_constraint, [:dogs, ["speed"]], { deferrable: :deferred, name: "uniq_speed" }, nil], @recorder.commands.first
      end

      def test_invert_remove_unique_constraint_constraint_without_options
        @recorder.revert do
          @recorder.remove_unique_constraint(:dogs, ["speed"])
        end
        assert_equal [:add_unique_constraint, [:dogs, ["speed"]], {}, nil], @recorder.commands.first
      end

      def test_invert_remove_unique_constraint_constraint_without_columns
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.remove_unique_constraint(:dogs, name: "uniq_speed")
          end
        end
      end

      def test_invert_create_enum
        @recorder.revert do
          @recorder.create_enum(:color, ["blue", "green"])
        end
        assert_equal [:drop_enum, [:color, ["blue", "green"]], {}, nil], @recorder.commands.first
      end

      def test_invert_drop_enum
        @recorder.revert do
          @recorder.drop_enum(:color, ["blue", "green"])
        end
        assert_equal [:create_enum, [:color, ["blue", "green"]], {}, nil], @recorder.commands.first
      end

      def test_invert_drop_enum_without_values
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.drop_enum(:color)
          end
        end

        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.drop_enum(:color, if_exists: true)
          end
        end
      end

      def test_invert_rename_enum
        @recorder.revert do
          @recorder.rename_enum(:dog_breed, :breed)
        end
        assert_equal [:rename_enum, [:breed, :dog_breed], {}], @recorder.commands.first
      end

      def test_invert_rename_enum_with_to_option
        @recorder.revert do
          @recorder.rename_enum(:dog_breed, to: :breed)
        end
        assert_equal [:rename_enum, [:breed, :dog_breed], {}], @recorder.commands.first
      end

      def test_invert_add_enum_value
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.add_enum_value(:dog_breed, :beagle)
          end
        end
      end

      def test_invert_rename_enum_value
        @recorder.revert do
          @recorder.rename_enum_value(:dog_breed, from: :retriever, to: :beagle)
        end
        assert_equal [:rename_enum_value, [:dog_breed], { from: :beagle, to: :retriever }], @recorder.commands.first
      end

      def test_invert_rename_enum_value_without_from
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.rename_enum_value(:dog_breed, to: :retriever)
          end
        end
      end

      def test_invert_rename_enum_value_without_to
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.rename_enum_value(:dog_breed, from: :beagle)
          end
        end
      end

      def test_invert_create_virtual_table
        @recorder.revert do
          @recorder.create_virtual_table(:searchables, :fts5, ["content", "meta UNINDEXED", "tokenize='porter ascii'"])
        end
        assert_equal [:drop_virtual_table, [:searchables, :fts5, ["content", "meta UNINDEXED", "tokenize='porter ascii'"]], {}, nil], @recorder.commands.first
      end

      def test_invert_drop_virtual_table
        @recorder.revert do
          @recorder.drop_virtual_table(:searchables, :fts5, ["title", "content"])
        end
        assert_equal [:create_virtual_table, [:searchables, :fts5, ["title", "content"]], {}, nil], @recorder.commands.first
      end

      def test_invert_drop_virtual_table_without_options
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.drop_virtual_table(:searchables)
          end
        end
      end

      def test_invert_drop_virtual_table_without_values
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert do
            @recorder.drop_virtual_table(:searchables, :fts5)
          end
        end
      end
    end
  end
end
