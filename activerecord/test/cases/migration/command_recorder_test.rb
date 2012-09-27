require "cases/helper"

module ActiveRecord
  class Migration
    class CommandRecorderTest < ActiveRecord::TestCase
      def setup
        @recorder = CommandRecorder.new
      end

      def test_respond_to_delegates
        recorder = CommandRecorder.new(Class.new {
          def america; end
        }.new)
        assert recorder.respond_to?(:america)
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
        assert recorder.respond_to?(:create_table), 'respond_to? create_table'
        recorder.send(:create_table, :horses)
        assert_equal [[:create_table, [:horses]]], recorder.commands
      end

      def test_unknown_commands_delegate
        recorder = CommandRecorder.new(stub(:foo => 'bar'))
        assert_equal 'bar', recorder.foo
      end

      def test_unknown_commands_raise_exception_if_they_cannot_delegate
        @recorder.record :execute, ['some sql']
        assert_raises(ActiveRecord::IrreversibleMigration) do
          @recorder.inverse
        end
      end

      def test_record
        @recorder.record :create_table, [:system_settings]
        assert_equal 1, @recorder.commands.length
      end

      def test_inverse
        @recorder.record :create_table, [:system_settings]
        assert_equal 1, @recorder.inverse.length

        @recorder.record :rename_table, [:old, :new]
        assert_equal 2, @recorder.inverse.length
      end

      def test_inverted_commands_are_reveresed
        @recorder.record :create_table, [:hello]
        @recorder.record :create_table, [:world]
        tables = @recorder.inverse.map(&:last)
        assert_equal [[:world], [:hello]], tables
      end

      def test_invert_create_table
        @recorder.record :create_table, [:system_settings]
        drop_table = @recorder.inverse.first
        assert_equal [:drop_table, [:system_settings]], drop_table
      end

      def test_invert_create_table_with_options
        @recorder.record :create_table, [:people_reminders, {:id => false}]
        drop_table = @recorder.inverse.first
        assert_equal [:drop_table, [:people_reminders]], drop_table
      end

      def test_invert_create_join_table
        @recorder.record :create_join_table, [:musics, :artists]
        drop_table = @recorder.inverse.first
        assert_equal [:drop_table, [:artists_musics]], drop_table
      end

      def test_invert_create_join_table_with_table_name
        @recorder.record :create_join_table, [:musics, :artists, {:table_name => :catalog}]
        drop_table = @recorder.inverse.first
        assert_equal [:drop_table, [:catalog]], drop_table
      end

      def test_invert_rename_table
        @recorder.record :rename_table, [:old, :new]
        rename = @recorder.inverse.first
        assert_equal [:rename_table, [:new, :old]], rename
      end

      def test_invert_add_column
        @recorder.record :add_column, [:table, :column, :type, {}]
        remove = @recorder.inverse.first
        assert_equal [:remove_column, [:table, :column]], remove
      end

      def test_invert_rename_column
        @recorder.record :rename_column, [:table, :old, :new]
        rename = @recorder.inverse.first
        assert_equal [:rename_column, [:table, :new, :old]], rename
      end

      def test_invert_add_index
        @recorder.record :add_index, [:table, [:one, :two], {:options => true}]
        remove = @recorder.inverse.first
        assert_equal [:remove_index, [:table, {:column => [:one, :two]}]], remove
      end

      def test_invert_add_index_with_name
        @recorder.record :add_index, [:table, [:one, :two], {:name => "new_index"}]
        remove = @recorder.inverse.first
        assert_equal [:remove_index, [:table, {:name => "new_index"}]], remove
      end

      def test_invert_add_index_with_no_options
        @recorder.record :add_index, [:table, [:one, :two]]
        remove = @recorder.inverse.first
        assert_equal [:remove_index, [:table, {:column => [:one, :two]}]], remove
      end

      def test_invert_rename_index
        @recorder.record :rename_index, [:table, :old, :new]
        rename = @recorder.inverse.first
        assert_equal [:rename_index, [:table, :new, :old]], rename
      end

      def test_invert_add_timestamps
        @recorder.record :add_timestamps, [:table]
        remove = @recorder.inverse.first
        assert_equal [:remove_timestamps, [:table]], remove
      end

      def test_invert_remove_timestamps
        @recorder.record :remove_timestamps, [:table]
        add = @recorder.inverse.first
        assert_equal [:add_timestamps, [:table]], add
      end

      def test_invert_add_reference
        @recorder.record :add_reference, [:table, :taggable, { polymorphic: true }]
        remove = @recorder.inverse.first
        assert_equal [:remove_reference, [:table, :taggable, { polymorphic: true }]], remove
      end

      def test_invert_add_belongs_to_alias
        @recorder.record :add_belongs_to, [:table, :user]
        remove = @recorder.inverse.first
        assert_equal [:remove_reference, [:table, :user]], remove
      end

      def test_invert_remove_reference
        @recorder.record :remove_reference, [:table, :taggable, { polymorphic: true }]
        add = @recorder.inverse.first
        assert_equal [:add_reference, [:table, :taggable, { polymorphic: true }]], add
      end

      def test_invert_remove_belongs_to_alias
        @recorder.record :remove_belongs_to, [:table, :user]
        add = @recorder.inverse.first
        assert_equal [:add_reference, [:table, :user]], add
      end
    end
  end
end
