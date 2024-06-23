# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class Migration
    class SayTest < ActiveRecord::TestCase
      def setup
        super
        $stdout, @original_stdout = StringIO.new, $stdout

        @original_verbose = ActiveRecord::Migration.verbose
        ActiveRecord::Migration.verbose = true
      end

      def teardown
        $stdout = @original_stdout

        ActiveRecord::Migration.verbose = @original_verbose
      end

      def test_migration_say_basic
        ActiveRecord::Migration.say("Foo")
        assert_equal "-- Foo\n", $stdout.string
      end

      def test_migration_say_true_subitem_false
        ActiveRecord::Migration.say("Foo", false)
        assert_equal "-- Foo\n", $stdout.string
      end

      def test_migration_say_true_subitem
        ActiveRecord::Migration.say("Foo", true)
        assert_equal "   -> Foo\n", $stdout.string
      end

      def test_migration_say_truthy_subitem
        ActiveRecord::Migration.say("Foo", :subitem)
        assert_equal "   -> Foo\n", $stdout.string
      end

      def test_migration_say_with_time_with_integer_returning_in_block
        ActiveRecord::Migration.say_with_time("Bar") { 123 }

        assert_equal <<~MSG, $stdout.string
          -- Bar
             -> 0.0000s
             -> 123 rows
        MSG
      end

      def test_migration_say_with_time_with_float_returning_in_block
        ActiveRecord::Migration.say_with_time("Bar") { 234.56 }

        assert_equal <<~MSG, $stdout.string
          -- Bar
             -> 0.0000s
        MSG
      end

      def test_migration_say_with_time_with_nil_returning_in_block
        ActiveRecord::Migration.say_with_time("Bar") { nil }

        assert_equal <<~MSG, $stdout.string
          -- Bar
             -> 0.0000s
        MSG
      end

      def test_migration_say_with_time_with_string_returning_in_block
        ActiveRecord::Migration.say_with_time("Bar") { "ignored" }

        assert_equal <<~MSG, $stdout.string
          -- Bar
             -> 0.0000s
        MSG
      end

      def test_migration_say_with_time_and_no_block_given
        error = assert_raises(ArgumentError) do
          ActiveRecord::Migration.say_with_time("Bar")
        end
        assert_equal "Missing block", error.message
      end
    end
  end
end
