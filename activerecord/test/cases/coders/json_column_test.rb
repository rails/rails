require "cases/helper"

module ActiveRecord
  module Coders
    class JSONColumnTest < ActiveRecord::TestCase
      def test_initialize_takes_class
        coder = JSONColumn.new(Object)
        assert_equal Object, coder.object_class
      end

      def test_type_mismatch_on_different_classes
        coder = JSONColumn.new(Array)
        assert_raises(SerializationTypeMismatch) do
          coder.load "{ \"foo\": \"bar\" }"
        end
      end

      def test_nil_is_ok
        coder = JSONColumn.new
        assert_nil coder.load ""
      end

      def test_returns_new_with_different_class
        coder = JSONColumn.new SerializationTypeMismatch
        assert_equal SerializationTypeMismatch, coder.load("").class
      end

      def test_returns_value_unless_is_a_string
        coder = JSONColumn.new
        assert_equal 235, coder.load(235)
      end

      def test_load_handles_other_classes
        coder = JSONColumn.new
        assert_equal [], coder.load([])
      end

      def test_load_swallows_json_exceptions
        coder = JSONColumn.new
        bad_json = '{ ]'
        assert_equal bad_json, coder.load(bad_json)
      end
    end
  end
end
