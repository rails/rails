require "cases/helper"
require "models/topic"
require "models/post"

module ActiveRecord
  class RelationTest < ActiveRecord::TestCase
    def test_scoped_responds_to_delegated_methods
      relation = Topic.all

      ["map", "uniq", "sort", "insert", "delete", "update"].each do |method|
        assert_respond_to relation, method, "Topic.all should respond to #{method.inspect}"
      end
    end

    def test_respond_to_delegates_to_relation
      relation = Topic.all
      fake_arel = Struct.new(:responds) {
        def respond_to? method, access = false
          responds << [method, access]
        end
      }.new []

      relation.extend(Module.new { attr_accessor :arel })
      relation.arel = fake_arel

      relation.respond_to?(:matching_attributes)
      assert_equal [:matching_attributes, false], fake_arel.responds.first

      fake_arel.responds = []
      relation.respond_to?(:matching_attributes, true)
      assert_equal [:matching_attributes, true], fake_arel.responds.first
    end

    def test_respond_to_dynamic_finders
      relation = Topic.all

      ["find_by_title", "find_by_title_and_author_name", "find_or_create_by_title", "find_or_initialize_by_title_and_author_name"].each do |method|
        assert_respond_to relation, method, "Topic.all should respond to #{method.inspect}"
      end
    end

    def test_respond_to_class_methods_and_scopes
      assert Topic.all.respond_to?(:by_lifo)
    end

  end
end
