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
        assert_equal [[:create_table, [:horses], nil]], recorder.commands
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

      def test_inverse_of_raise_exception_on_unknown_commands
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :execute, ["some sql"]
        end
      end

      def test_irreversible_commands_raise_exception
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.revert { @recorder.execute "some sql" }
        end
      end

      def test_record
        @recorder.record :create_table, [:system_settings]
        assert_equal 1, @recorder.commands.length
      end

      def test_inverted_commands_are_reversed
        @recorder.revert do
          @recorder.record :create_table, [:hello]
          @recorder.record :create_table, [:world]
        end
        tables = @recorder.commands.map { |_cmd, args, _block| args }
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
        assert_equal [[:create_table, ["apples"], block], [:drop_table, ["elderberries"], nil],
                      [:create_table, ["clementines"], block], [:create_table, ["dates"], nil],
                      [:drop_table, ["bananas"], block], [:drop_table, ["grapes"], nil],
                      [:drop_table, ["figs"], block]], @recorder.commands
      end

      def test_invert_change_table
        @recorder.revert do
          @recorder.change_table :fruits do |t|
            t.string :name
            t.rename :kind, :cultivar
          end
        end

        assert_equal [
          [:rename_column, [:fruits, :cultivar, :kind]],
          [:remove_column, [:fruits, :name, :string], nil],
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
            [:change_table, [:fruits]],
            [:change_table, [:fruits]]
          ], @recorder.commands.map { |command| command[0...-1] }
        end
      end

      def test_invert_create_table
        @recorder.revert do
          @recorder.record :create_table, [:system_settings]
        end
        drop_table = @recorder.commands.first
        assert_equal [:drop_table, [:system_settings], nil], drop_table
      end

      def test_invert_create_table_with_if_not_exists
        @recorder.revert do
          @recorder.record :create_table, [:system_settings, if_not_exists: true]
        end
        drop_table = @recorder.commands.first
        assert_equal [:drop_table, [:system_settings, {}], nil], drop_table
      end

      def test_invert_create_table_with_options_and_block
        block = Proc.new { }
        drop_table = @recorder.inverse_of :create_table, [:people_reminders, id: false], &block
        assert_equal [:drop_table, [:people_reminders, id: false], block], drop_table
      end

      def test_invert_drop_table
        block = Proc.new { }
        create_table = @recorder.inverse_of :drop_table, [:people_reminders, id: false], &block
        assert_equal [:create_table, [:people_reminders, id: false], block], create_table
      end

      def test_invert_drop_table_with_if_exists
        block = Proc.new { }
        create_table = @recorder.inverse_of :drop_table, [:people_reminders, id: false, if_exists: true], &block
        assert_equal [:create_table, [:people_reminders, id: false], block], create_table
      end

      def test_invert_drop_table_without_a_block_nor_option
        assert_raises(ActiveRecord::IrreversibleMigration, match: "To avoid mistakes, drop_table is only reversible if given options or a block (can be empty).") do
          @recorder.inverse_of :drop_table, [:people_reminders]
        end
      end

      def test_invert_drop_table_with_multiple_tables
        assert_raises(ActiveRecord::IrreversibleMigration, match: "To avoid mistakes, drop_table is only reversible if given a single table name.") do
          @recorder.inverse_of :drop_table, [:musics, :artists]
        end
      end

      def test_invert_drop_table_with_multiple_tables_and_options
        assert_raises(ActiveRecord::IrreversibleMigration, match: "To avoid mistakes, drop_table is only reversible if given a single table name.") do
          @recorder.inverse_of :drop_table, [:musics, :artists, id: false]
        end
      end

      def test_invert_drop_table_with_multiple_tables_and_block
        block = Proc.new { }

        assert_raises(ActiveRecord::IrreversibleMigration, match: "To avoid mistakes, drop_table is only reversible if given a single table name.") do
          @recorder.inverse_of :drop_table, [:musics, :artists], &block
        end
      end

      def test_invert_create_join_table
        drop_join_table = @recorder.inverse_of :create_join_table, [:musics, :artists]
        assert_equal [:drop_join_table, [:musics, :artists], nil], drop_join_table
      end

      def test_invert_create_join_table_with_table_name
        drop_join_table = @recorder.inverse_of :create_join_table, [:musics, :artists, table_name: :catalog]
        assert_equal [:drop_join_table, [:musics, :artists, table_name: :catalog], nil], drop_join_table
      end

      def test_invert_drop_join_table
        block = Proc.new { }
        create_join_table = @recorder.inverse_of :drop_join_table, [:musics, :artists, table_name: :catalog], &block
        assert_equal [:create_join_table, [:musics, :artists, table_name: :catalog], block], create_join_table
      end

      def test_invert_rename_table
        rename = @recorder.inverse_of :rename_table, [:old, :new]
        assert_equal [:rename_table, [:new, :old]], rename
      end

      def test_invert_add_column
        remove = @recorder.inverse_of :add_column, [:table, :column, :type, {}]
        assert_equal [:remove_column, [:table, :column, :type, {}], nil], remove
      end

      def test_invert_change_column
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :change_column, [:table, :column, :type, {}]
        end
      end

      def test_invert_change_column_default
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :change_column_default, [:table, :column, "default_value"]
        end
      end

      def test_invert_change_column_default_with_from_and_to
        change = @recorder.inverse_of :change_column_default, [:table, :column, from: "old_value", to: "new_value"]
        assert_equal [:change_column_default, [:table, :column, from: "new_value", to: "old_value"]], change
      end

      def test_invert_change_column_default_with_from_and_to_with_boolean
        change = @recorder.inverse_of :change_column_default, [:table, :column, from: true, to: false]
        assert_equal [:change_column_default, [:table, :column, from: false, to: true]], change
      end

      if ActiveRecord::Base.lease_connection.supports_comments?
        def test_invert_change_column_comment
          assert_raises(ActiveRecord::IrreversibleMigration) do
            @recorder.inverse_of :change_column_comment, [:table, :column, "comment"]
          end
        end

        def test_invert_change_column_comment_with_from_and_to
          change = @recorder.inverse_of :change_column_comment, [:table, :column, from: "old_value", to: "new_value"]
          assert_equal [:change_column_comment, [:table, :column, from: "new_value", to: "old_value"]], change
        end

        def test_invert_change_column_comment_with_from_and_to_with_nil
          change = @recorder.inverse_of :change_column_comment, [:table, :column, from: nil, to: "new_value"]
          assert_equal [:change_column_comment, [:table, :column, from: "new_value", to: nil]], change
        end

        def test_invert_change_table_comment
          assert_raises(ActiveRecord::IrreversibleMigration) do
            @recorder.inverse_of :change_column_comment, [:table, :column, "comment"]
          end
        end

        def test_invert_change_table_comment_with_from_and_to
          change = @recorder.inverse_of :change_table_comment, [:table, from: "old_value", to: "new_value"]
          assert_equal [:change_table_comment, [:table, from: "new_value", to: "old_value"]], change
        end

        def test_invert_change_table_comment_with_from_and_to_with_nil
          change = @recorder.inverse_of :change_table_comment, [:table, from: nil, to: "new_value"]
          assert_equal [:change_table_comment, [:table, from: "new_value", to: nil]], change
        end
      end

      def test_invert_change_column_null
        add = @recorder.inverse_of :change_column_null, [:table, :column, true]
        assert_equal [:change_column_null, [:table, :column, false]], add
      end

      def test_invert_remove_column
        add = @recorder.inverse_of :remove_column, [:table, :column, :type, {}]
        assert_equal [:add_column, [:table, :column, :type, {}], nil], add
      end

      def test_invert_remove_column_without_type
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :remove_column, [:table, :column]
        end
      end

      def test_invert_rename_column
        rename = @recorder.inverse_of :rename_column, [:table, :old, :new]
        assert_equal [:rename_column, [:table, :new, :old]], rename
      end

      def test_invert_add_index
        remove = @recorder.inverse_of :add_index, [:table, [:one, :two]]
        assert_equal [:remove_index, [:table, [:one, :two]], nil], remove
      end

      def test_invert_add_index_with_name
        remove = @recorder.inverse_of :add_index, [:table, [:one, :two], name: "new_index"]
        assert_equal [:remove_index, [:table, [:one, :two], name: "new_index"], nil], remove
      end

      def test_invert_add_index_with_algorithm_option
        remove = @recorder.inverse_of :add_index, [:table, :one, algorithm: :concurrently]
        assert_equal [:remove_index, [:table, :one, algorithm: :concurrently], nil], remove
      end

      def test_invert_remove_index
        add = @recorder.inverse_of :remove_index, [:table, :one]
        assert_equal [:add_index, [:table, :one]], add
      end

      def test_invert_remove_index_with_positional_column
        add = @recorder.inverse_of :remove_index, [:table, [:one, :two], { options: true }]
        assert_equal [:add_index, [:table, [:one, :two], options: true]], add
      end

      def test_invert_remove_index_with_column
        add = @recorder.inverse_of :remove_index, [:table, { column: [:one, :two], options: true }]
        assert_equal [:add_index, [:table, [:one, :two], options: true]], add
      end

      def test_invert_remove_index_with_name
        add = @recorder.inverse_of :remove_index, [:table, { column: [:one, :two], name: "new_index" }]
        assert_equal [:add_index, [:table, [:one, :two], name: "new_index"]], add
      end

      def test_invert_remove_index_with_no_special_options
        add = @recorder.inverse_of :remove_index, [:table, { column: [:one, :two] }]
        assert_equal [:add_index, [:table, [:one, :two]]], add
      end

      def test_invert_remove_index_with_no_column
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :remove_index, [:table, name: "new_index"]
        end
      end

      def test_invert_rename_index
        rename = @recorder.inverse_of :rename_index, [:table, :old, :new]
        assert_equal [:rename_index, [:table, :new, :old]], rename
      end

      def test_invert_add_timestamps
        remove = @recorder.inverse_of :add_timestamps, [:table]
        assert_equal [:remove_timestamps, [:table], nil], remove
      end

      def test_invert_remove_timestamps
        add = @recorder.inverse_of :remove_timestamps, [:table, { null: true }]
        assert_equal [:add_timestamps, [:table, { null: true }], nil], add
      end

      def test_invert_add_reference
        remove = @recorder.inverse_of :add_reference, [:table, :taggable, { polymorphic: true }]
        assert_equal [:remove_reference, [:table, :taggable, { polymorphic: true }], nil], remove
      end

      def test_invert_add_belongs_to_alias
        remove = @recorder.inverse_of :add_belongs_to, [:table, :user]
        assert_equal [:remove_reference, [:table, :user], nil], remove
      end

      def test_invert_remove_reference
        add = @recorder.inverse_of :remove_reference, [:table, :taggable, { polymorphic: true }]
        assert_equal [:add_reference, [:table, :taggable, { polymorphic: true }], nil], add
      end

      def test_invert_remove_reference_with_index_and_foreign_key
        add = @recorder.inverse_of :remove_reference, [:table, :taggable, { index: true, foreign_key: true }]
        assert_equal [:add_reference, [:table, :taggable, { index: true, foreign_key: true }], nil], add
      end

      def test_invert_remove_belongs_to_alias
        add = @recorder.inverse_of :remove_belongs_to, [:table, :user]
        assert_equal [:add_reference, [:table, :user], nil], add
      end

      def test_invert_enable_extension
        disable = @recorder.inverse_of :enable_extension, ["uuid-ossp"]
        assert_equal [:disable_extension, ["uuid-ossp"], nil], disable
      end

      def test_invert_disable_extension
        enable = @recorder.inverse_of :disable_extension, ["uuid-ossp"]
        assert_equal [:enable_extension, ["uuid-ossp"], nil], enable
      end

      def test_invert_create_schema
        disable = @recorder.inverse_of :create_schema, ["myschema"]
        assert_equal [:drop_schema, ["myschema"], nil], disable
      end

      def test_invert_drop_schema
        enable = @recorder.inverse_of :drop_schema, ["myschema"]
        assert_equal [:create_schema, ["myschema"], nil], enable
      end

      def test_invert_add_foreign_key
        enable = @recorder.inverse_of :add_foreign_key, [:dogs, :people]
        assert_equal [:remove_foreign_key, [:dogs, :people], nil], enable
      end

      def test_invert_remove_foreign_key
        enable = @recorder.inverse_of :remove_foreign_key, [:dogs, :people]
        assert_equal [:add_foreign_key, [:dogs, :people]], enable
      end

      def test_invert_add_foreign_key_with_column
        enable = @recorder.inverse_of :add_foreign_key, [:dogs, :people, column: "owner_id"]
        assert_equal [:remove_foreign_key, [:dogs, :people, column: "owner_id"], nil], enable
      end

      def test_invert_remove_foreign_key_with_column
        enable = @recorder.inverse_of :remove_foreign_key, [:dogs, :people, column: "owner_id"]
        assert_equal [:add_foreign_key, [:dogs, :people, column: "owner_id"]], enable
      end

      def test_invert_add_foreign_key_with_column_and_name
        enable = @recorder.inverse_of :add_foreign_key, [:dogs, :people, column: "owner_id", name: "fk"]
        assert_equal [:remove_foreign_key, [:dogs, :people, column: "owner_id", name: "fk"], nil], enable
      end

      def test_invert_remove_foreign_key_with_column_and_name
        enable = @recorder.inverse_of :remove_foreign_key, [:dogs, :people, column: "owner_id", name: "fk"]
        assert_equal [:add_foreign_key, [:dogs, :people, column: "owner_id", name: "fk"]], enable
      end

      def test_invert_remove_foreign_key_with_primary_key
        enable = @recorder.inverse_of :remove_foreign_key, [:dogs, :people, primary_key: "person_id"]
        assert_equal [:add_foreign_key, [:dogs, :people, primary_key: "person_id"]], enable
      end

      def test_invert_remove_foreign_key_with_primary_key_and_to_table_in_options
        enable = @recorder.inverse_of :remove_foreign_key, [:dogs, to_table: :people, primary_key: "uuid"]
        assert_equal [:add_foreign_key, [:dogs, :people, primary_key: "uuid"]], enable
      end

      def test_invert_remove_foreign_key_with_on_delete_on_update
        enable = @recorder.inverse_of :remove_foreign_key, [:dogs, :people, on_delete: :nullify, on_update: :cascade]
        assert_equal [:add_foreign_key, [:dogs, :people, on_delete: :nullify, on_update: :cascade]], enable
      end

      def test_invert_remove_foreign_key_with_to_table_in_options
        enable = @recorder.inverse_of :remove_foreign_key, [:dogs, to_table: :people]
        assert_equal [:add_foreign_key, [:dogs, :people]], enable

        enable = @recorder.inverse_of :remove_foreign_key, [:dogs, to_table: :people, column: :owner_id]
        assert_equal [:add_foreign_key, [:dogs, :people, column: :owner_id]], enable
      end

      def test_invert_remove_foreign_key_is_irreversible_without_to_table
        assert_raises ActiveRecord::IrreversibleMigration do
          @recorder.inverse_of :remove_foreign_key, [:dogs, column: "owner_id"]
        end

        assert_raises ActiveRecord::IrreversibleMigration do
          @recorder.inverse_of :remove_foreign_key, [:dogs, name: "fk"]
        end

        assert_raises ActiveRecord::IrreversibleMigration do
          @recorder.inverse_of :remove_foreign_key, [:dogs]
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
        enable = @recorder.inverse_of :add_check_constraint, [:dogs, "speed > 0", name: "speed_check"]
        assert_equal [:remove_check_constraint, [:dogs, "speed > 0", name: "speed_check"], nil], enable
      end

      def test_invert_add_check_constraint_if_not_exists
        enable = @recorder.inverse_of :add_check_constraint, [:dogs, "speed > 0", name: "speed_check", if_not_exists: true]
        assert_equal [:remove_check_constraint, [:dogs, "speed > 0", name: "speed_check", if_exists: true], nil], enable
      end

      def test_invert_remove_check_constraint
        enable = @recorder.inverse_of :remove_check_constraint, [:dogs, "speed > 0", name: "speed_check"]
        assert_equal [:add_check_constraint, [:dogs, "speed > 0", name: "speed_check"], nil], enable
      end

      def test_invert_remove_check_constraint_without_expression
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :remove_check_constraint, [:dogs]
        end
      end

      def test_invert_remove_check_constraint_if_exists
        enable = @recorder.inverse_of :remove_check_constraint, [:dogs, "speed > 0", name: "speed_check", if_exists: true]
        assert_equal [:add_check_constraint, [:dogs, "speed > 0", name: "speed_check", if_not_exists: true], nil], enable
      end

      def test_invert_add_unique_constraint_constraint_with_using_index
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :add_unique_constraint, [:dogs, using_index: "unique_index"]
        end
      end

      def test_invert_remove_unique_constraint_constraint
        enable = @recorder.inverse_of :remove_unique_constraint, [:dogs, ["speed"], deferrable: :deferred, name: "uniq_speed"]
        assert_equal [:add_unique_constraint, [:dogs, ["speed"], deferrable: :deferred, name: "uniq_speed"], nil], enable
      end

      def test_invert_remove_unique_constraint_constraint_without_options
        enable = @recorder.inverse_of :remove_unique_constraint, [:dogs, ["speed"]]
        assert_equal [:add_unique_constraint, [:dogs, ["speed"]], nil], enable
      end

      def test_invert_remove_unique_constraint_constraint_without_columns
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :remove_unique_constraint, [:dogs, name: "uniq_speed"]
        end
      end

      def test_invert_create_enum
        drop = @recorder.inverse_of :create_enum, [:color, ["blue", "green"]]
        assert_equal [:drop_enum, [:color, ["blue", "green"]], nil], drop
      end

      def test_invert_drop_enum
        create = @recorder.inverse_of :drop_enum, [:color, ["blue", "green"]]
        assert_equal [:create_enum, [:color, ["blue", "green"]], nil], create
      end

      def test_invert_drop_enum_without_values
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :drop_enum, [:color]
        end

        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :drop_enum, [:color, if_exists: true]
        end
      end

      def test_invert_rename_enum
        enum = @recorder.inverse_of :rename_enum, [:dog_breed, :breed]
        assert_equal [:rename_enum, [:breed, :dog_breed]], enum
      end

      def test_invert_rename_enum_with_to_option
        enum = @recorder.inverse_of :rename_enum, [:dog_breed, to: :breed]
        assert_equal [:rename_enum, [:breed, :dog_breed]], enum
      end

      def test_invert_add_enum_value
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :add_enum_value, [:dog_breed, :beagle]
        end
      end

      def test_invert_rename_enum_value
        enum_value = @recorder.inverse_of :rename_enum_value, [:dog_breed, from: :retriever, to: :beagle]
        assert_equal [:rename_enum_value, [:dog_breed, from: :beagle, to: :retriever]], enum_value
      end

      def test_invert_rename_enum_value_without_from
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :rename_enum_value, [:dog_breed, to: :retriever]
        end
      end

      def test_invert_rename_enum_value_without_to
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :rename_enum_value, [:dog_breed, from: :beagle]
        end
      end

      def test_invert_create_virtual_table
        drop = @recorder.inverse_of :create_virtual_table, [:searchables, :fts5, ["content", "meta UNINDEXED", "tokenize='porter ascii'"]]
        assert_equal [:drop_virtual_table, [:searchables, :fts5, ["content", "meta UNINDEXED", "tokenize='porter ascii'"]], nil], drop
      end

      def test_invert_drop_virtual_table
        create = @recorder.inverse_of :drop_virtual_table, [:searchables, :fts5, ["title", "content"]]
        assert_equal [:create_virtual_table, [:searchables, :fts5, ["title", "content"]], nil], create
      end

      def test_invert_drop_virtual_table_without_options
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse_of :drop_virtual_table, [:searchables]
        end
      end
    end
  end
end
