
require "cases/helper"

module ActiveRecord
  module Coders
    class YAMLColumnTest < ActiveRecord::TestCase
      def test_initialize_takes_class
        coder = YAMLColumn.new(Object)
        assert_equal Object, coder.object_class
      end

      def test_type_mismatch_on_different_classes_on_dump
        coder = YAMLColumn.new(Array)
        assert_raises(SerializationTypeMismatch) do
          coder.dump("a")
        end
      end

      def test_type_mismatch_on_different_classes
        coder = YAMLColumn.new(Array)
        assert_raises(SerializationTypeMismatch) do
          coder.load "--- foo"
        end
      end

      def test_nil_is_ok
        coder = YAMLColumn.new
        assert_nil coder.load "--- "
      end

      def test_returns_new_with_different_class
        coder = YAMLColumn.new SerializationTypeMismatch
        assert_equal SerializationTypeMismatch, coder.load("--- ").class
      end

      def test_returns_string_unless_starts_with_dash
        coder = YAMLColumn.new
        assert_equal 'foo', coder.load("foo")
      end

      def test_load_handles_other_classes
        coder = YAMLColumn.new
        assert_equal [], coder.load([])
      end

      def test_load_swallows_yaml_exceptions
        coder = YAMLColumn.new
        bad_yaml = '--- {'
        assert_equal bad_yaml, coder.load(bad_yaml)
      end
    end
  end
end
