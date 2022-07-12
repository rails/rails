# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module Coders
    class YAMLColumnTest < ActiveRecord::TestCase
      setup do
        ActiveRecord::Base.use_yaml_unsafe_load = true
      end

      def test_initialize_takes_class
        coder = YAMLColumn.new("attr_name", Object)
        assert_equal Object, coder.object_class
      end

      def test_type_mismatch_on_different_classes_on_dump
        coder = YAMLColumn.new("tags", Array)
        error = assert_raises(SerializationTypeMismatch) do
          coder.dump("a")
        end
        assert_equal %{can't dump `tags`: was supposed to be a Array, but was a String. -- "a"}, error.to_s
      end

      def test_type_mismatch_on_different_classes
        coder = YAMLColumn.new("tags", Array)
        error = assert_raises(SerializationTypeMismatch) do
          coder.load "--- foo"
        end
        assert_equal %{can't load `tags`: was supposed to be a Array, but was a String. -- "foo"}, error.to_s
      end

      def test_nil_is_ok
        coder = YAMLColumn.new("attr_name")
        assert_nil coder.load "--- "
      end

      def test_returns_new_with_different_class
        coder = YAMLColumn.new("attr_name", SerializationTypeMismatch)
        assert_equal SerializationTypeMismatch, coder.load("--- ").class
      end

      def test_returns_string_unless_starts_with_dash
        coder = YAMLColumn.new("attr_name")
        assert_equal "foo", coder.load("foo")
      end

      def test_load_handles_other_classes
        coder = YAMLColumn.new("attr_name")
        assert_equal [], coder.load([])
      end

      def test_load_doesnt_swallow_yaml_exceptions
        coder = YAMLColumn.new("attr_name")
        bad_yaml = "--- {"
        assert_raises(Psych::SyntaxError) do
          coder.load(bad_yaml)
        end
      end

      def test_load_doesnt_handle_undefined_class_or_module
        coder = YAMLColumn.new("attr_name")
        missing_class_yaml = '--- !ruby/object:DoesNotExistAndShouldntEver {}\n'
        assert_raises(ArgumentError) do
          coder.load(missing_class_yaml)
        end
      end
    end

    class YAMLColumnTestWithSafeLoad < YAMLColumnTest
      setup do
        @yaml_column_permitted_classes_default = ActiveRecord::Base.yaml_column_permitted_classes
        ActiveRecord::Base.use_yaml_unsafe_load = false
      end

      def test_yaml_column_permitted_classes_are_consumed_by_safe_load
        ActiveRecord::Base.yaml_column_permitted_classes = [Symbol, Time]

        coder = YAMLColumn.new("attr_name")
        time_yaml = YAML.dump(Time.new)
        symbol_yaml = YAML.dump(:somesymbol)

        assert_nothing_raised do
          coder.load(time_yaml)
          coder.load(symbol_yaml)
        end

        ActiveRecord::Base.yaml_column_permitted_classes = @yaml_column_permitted_classes_default
      end

      def test_load_doesnt_handle_undefined_class_or_module
        coder = YAMLColumn.new("attr_name")
        missing_class_yaml = '--- !ruby/object:DoesNotExistAndShouldntEver {}\n'
        assert_raises(Psych::DisallowedClass) do
          coder.load(missing_class_yaml)
        end
      end
    end
  end
end
