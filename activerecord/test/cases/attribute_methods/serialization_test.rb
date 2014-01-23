require "cases/helper"
require 'models/topic'

module ActiveRecord
  module AttributeMethods
    class SerializationTest < ActiveSupport::TestCase
      class FakeColumn < Struct.new(:name)
        def type; :integer; end
        def type_cast(s); "#{s}!"; end
      end

      class NullCoder
        def load(v); v; end
      end

      def test_type_cast_serialized_value
        value = Serialization::Attribute.new(NullCoder.new, "Hello world", :serialized)
        type = Serialization::Type.new(FakeColumn.new)
        assert_equal "Hello world!", type.type_cast(value)
      end

      def test_type_cast_unserialized_value
        value = Serialization::Attribute.new(nil, "Hello world", :unserialized)
        type = Serialization::Type.new(FakeColumn.new)
        type.type_cast(value)
        assert_equal "Hello world", type.type_cast(value)
      end

      def test_attribute_hash_mutation
        topic = Topic.create!(:content => {:a => "a"})
        assert !topic.content_changed?
        assert !topic.changed?
        assert_equal [], topic.changed_hashes
        assert !topic.changed_hashes?

        topic.content[:a] = "b"
        assert topic.changed_hash?("content")
        assert_equal ["content"], topic.changed_hashes
        assert topic.changed_hashes?
        assert topic.changed?

        topic.content[:a] = "a"
        assert !topic.changed_hash?("content")
        assert !topic.changed?

        topic = Topic.find_by_id!(topic.id)
        assert !topic.changed_hashes?
        topic.content[:a] = "b"
        assert topic.changed_hash?("content")
      end


      def test_changed_should_detect_when_serialized_attribute_changes
        topic = Topic.create!(:content => {:a => "a"})
        topic.content[:b] = "b"
        assert topic.content_changed?
        assert topic.changed?
        assert_equal({:a => "a", :b => "b"}, topic.content_was) #bug
        assert_equal nil, topic.content_change #bug
        topic.save!
        assert !topic.content_changed?
        assert !topic.changed?
        assert_equal "b", topic.content[:b]
        topic.reload
        assert_equal "b", topic.content[:b]
      end

      def test_save_should_update_timestamps_when_serialized_attributes_change
        topic = Topic.create!(:content => {:a => "a"})
        topic.save!

        updated_at = topic.updated_at
        topic.content[:hello] = 'world'
        topic.save!

        assert_not_equal updated_at, topic.updated_at
        assert_equal 'world', topic.content[:hello]
      end

      def test_save_should_not_update_timestamps_when_serialized_are_unchanged
        topic = Topic.create!(:content => {:a => "a"})
        topic.save!

        updated_at = topic.updated_at
        topic.save!

        assert_equal updated_at, topic.updated_at
      end

      def test_save_should_not_save_serialized_attribute_if_not_present
        Topic.create!(:author_name => 'Bill', :content => {:a => "a"})
        topic = Topic.select('id, author_name').first
        topic.update_columns author_name: 'John'
        topic = Topic.first
        assert_not_nil topic.content
      end
    end
  end
end
