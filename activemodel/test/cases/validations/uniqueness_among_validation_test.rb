# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/person"

class UniquenessAmongValidationTest < ActiveModel::TestCase
  def setup
    # Define accessors for Person if needed
    unless Person.method_defined?(:first_name)
      Person.class_eval do
        attr_accessor :first_name, :last_name
      end
    end
  end

  def teardown
    Topic.clear_validators!
    Person.clear_validators!
  end

  # Helper method to define array accessors
  def define_array_accessors_on_topic
    # Only define them once to avoid warnings
    unless Topic.method_defined?(:tags_list)
      Topic.class_eval do
        def tags_list
          @tags_list ||= []
        end

        attr_writer :tags_list

        def categories
          @categories ||= []
        end

        attr_writer :categories
      end
    end
  end

  # Helper method to define hash accessors
  def define_hash_accessors_on_topic
    # Only define them once to avoid warnings
    unless Topic.method_defined?(:metadata)
      Topic.class_eval do
        def metadata
          @metadata ||= {}
        end

        attr_writer :metadata

        def properties
          @properties ||= {}
        end

        attr_writer :properties
      end
    end
  end

  def test_validates_uniqueness_of_among_with_same_values
    Topic.validates_uniqueness_of_among :title, :author_name

    t = Topic.new(title: "Same Value", author_name: "Same Value")
    assert_predicate t, :invalid?
    assert_equal ["has already been taken among author_name"], t.errors[:title]
    assert_equal ["has already been taken among title"], t.errors[:author_name]
  end

  def test_validates_uniqueness_of_among_with_different_values
    Topic.validates_uniqueness_of_among :title, :author_name

    t = Topic.new(title: "Different Title", author_name: "Different Author")
    assert_predicate t, :valid?
  end

  def test_validates_uniqueness_of_among_with_custom_message
    Topic.validates_uniqueness_of_among :title, :author_name, message: "must be different from %{attributes}"

    t = Topic.new(title: "Same Value", author_name: "Same Value")
    assert_predicate t, :invalid?
    assert_equal ["must be different from author_name"], t.errors[:title]
    assert_equal ["must be different from title"], t.errors[:author_name]
  end

  def test_validates_uniqueness_of_among_with_allow_nil
    Topic.validates_uniqueness_of_among :title, :author_name, allow_nil: true

    t = Topic.new(title: nil, author_name: "Value")
    assert_predicate t, :valid?

    t.author_name = nil
    assert_predicate t, :valid?

    # Both nil should be valid since they're not compared
    t.title = nil
    assert_predicate t, :valid?
  end

  def test_validates_uniqueness_of_among_with_allow_blank
    Topic.validates_uniqueness_of_among :title, :author_name, allow_blank: true

    t = Topic.new(title: "", author_name: "Value")
    assert_predicate t, :valid?

    t.author_name = ""
    assert_predicate t, :valid?

    # Both blank should be valid since they're not compared
    t.title = ""
    assert_predicate t, :valid?
  end

  def test_validates_uniqueness_of_among_with_case_sensitivity
    Topic.validates_uniqueness_of_among :title, :author_name, case_sensitive: true

    t = Topic.new(title: "Value", author_name: "value")
    assert_predicate t, :valid?

    t.author_name = "Value"
    assert_predicate t, :invalid?
  end

  def test_validates_uniqueness_of_among_without_case_sensitivity
    Topic.validates_uniqueness_of_among :title, :author_name, case_sensitive: false

    t = Topic.new(title: "Value", author_name: "value")
    assert_predicate t, :invalid?
    assert_equal ["has already been taken among author_name"], t.errors[:title]
    assert_equal ["has already been taken among title"], t.errors[:author_name]
  end

  def test_validates_uniqueness_of_among_with_custom_attributes
    Topic.validates_uniqueness_of_among :title, in: [:author_name, :content]

    t = Topic.new(title: "Value", author_name: "Value", content: "Different")
    assert_predicate t, :invalid?
    assert_equal ["has already been taken among author_name"], t.errors[:title]

    t.title = "Value"
    t.author_name = "Different"
    t.content = "Value"
    assert_predicate t, :invalid?
    assert_equal ["has already been taken among content"], t.errors[:title]
  end

  def test_validates_uniqueness_of_among_with_multiple_duplicates
    Topic.validates_uniqueness_of_among :title, :author_name, :content

    t = Topic.new(title: "Same", author_name: "Same", content: "Same")
    assert_predicate t, :invalid?
    assert_equal ["has already been taken among author_name, content"], t.errors[:title]
    assert_equal ["has already been taken among title, content"], t.errors[:author_name]
    assert_equal ["has already been taken among title, author_name"], t.errors[:content]
  end

  def test_validates_uniqueness_of_among_for_ruby_class
    Person.validates_uniqueness_of_among :first_name, :last_name

    p = Person.new
    p.first_name = "John"
    p.last_name = "John"
    assert_predicate p, :invalid?
    assert_equal ["has already been taken among last_name"], p.errors[:first_name]
    assert_equal ["has already been taken among first_name"], p.errors[:last_name]

    p.last_name = "Doe"
    assert_predicate p, :valid?
  end

  def test_validates_uniqueness_of_among_with_array_values
    define_array_accessors_on_topic
    Topic.validates_uniqueness_of_among :tags_list, :categories

    topic = Topic.new
    topic.tags_list = [1, 2, 3]
    topic.categories = [4, 5, 6]
    assert_predicate topic, :valid?

    topic.categories = [1, 2, 3]
    assert_predicate topic, :invalid?
    assert_equal ["has already been taken among categories"], topic.errors[:tags_list]
    assert_equal ["has already been taken among tags_list"], topic.errors[:categories]
  end

  def test_validates_uniqueness_of_among_with_array_values_different_order
    define_array_accessors_on_topic
    Topic.validates_uniqueness_of_among :tags_list, :categories

    topic = Topic.new
    topic.tags_list = [1, 2, 3]
    topic.categories = [3, 2, 1]
    assert_predicate topic, :invalid?
    assert_equal ["has already been taken among categories"], topic.errors[:tags_list]
    assert_equal ["has already been taken among tags_list"], topic.errors[:categories]
  end

  def test_validates_uniqueness_of_among_with_partial_array_overlap
    define_array_accessors_on_topic
    Topic.validates_uniqueness_of_among :tags_list, :categories

    topic = Topic.new
    topic.tags_list = [1, 2, 3]
    topic.categories = [3, 4, 5]
    assert_predicate topic, :valid?, "Arrays with partial overlap should be valid"

    topic.categories = [1, 2, 3, 4]
    assert_predicate topic, :valid?, "Arrays with partial overlap should be valid"
  end

  def test_validates_uniqueness_of_among_with_unsortable_array_elements
    define_array_accessors_on_topic
    Topic.validates_uniqueness_of_among :tags_list, :categories

    # Complex objects that can't be sorted
    complex1 = Object.new
    complex2 = Object.new

    topic = Topic.new
    topic.tags_list = [complex1, complex2]
    topic.categories = [complex1, complex2]

    # Should be invalid because the arrays contain the same elements even though they can't be sorted
    assert_predicate topic, :invalid?
    assert_equal ["has already been taken among categories"], topic.errors[:tags_list]
    assert_equal ["has already been taken among tags_list"], topic.errors[:categories]
  end

  def test_validates_uniqueness_of_among_with_hash_values
    define_hash_accessors_on_topic
    Topic.validates_uniqueness_of_among :metadata, :properties

    topic = Topic.new
    topic.metadata = { "author" => "John", "year" => 2023 }
    topic.properties = { "year" => 2023, "author" => "John" }

    assert_predicate topic, :invalid?
    assert_equal ["has already been taken among properties"], topic.errors[:metadata]
    assert_equal ["has already been taken among metadata"], topic.errors[:properties]

    # Different hashes should be valid
    topic = Topic.new
    topic.metadata = { "author" => "John", "year" => 2023 }
    topic.properties = { "author" => "Jane", "year" => 2023 }
    assert_predicate topic, :valid?
  end

  def test_validates_uniqueness_of_among_with_hash_values_different_key_types
    define_hash_accessors_on_topic
    Topic.validates_uniqueness_of_among :metadata, :properties

    topic = Topic.new
    # String keys vs Symbol keys should be considered different by default
    topic.metadata = { "author" => "John", "year" => 2023 }
    topic.properties = { author: "John", year: 2023 }

    assert_predicate topic, :valid?

    # Explicitly compare as strings to consider them the same
    Topic.clear_validators!
    Topic.validates_uniqueness_of_among :metadata, :properties, compare_hash_keys_as_strings: true

    assert_predicate topic, :invalid?
    assert_equal ["has already been taken among properties"], topic.errors[:metadata]
    assert_equal ["has already been taken among metadata"], topic.errors[:properties]
  end

  def test_validates_uniqueness_of_among_with_nested_hash_values
    define_hash_accessors_on_topic
    Topic.validates_uniqueness_of_among :metadata, :properties

    topic = Topic.new
    topic.metadata = { "author" => { "name" => "John", "email" => "john@example.com" }, "year" => 2023 }
    topic.properties = { "year" => 2023, "author" => { "name" => "John", "email" => "john@example.com" } }

    assert_predicate topic, :invalid?

    # Different nested hash values should be valid
    topic = Topic.new
    topic.metadata = { "author" => { "name" => "John", "email" => "john@example.com" }, "year" => 2023 }
    topic.properties = { "year" => 2023, "author" => { "name" => "Jane", "email" => "jane@example.com" } }
    assert_predicate topic, :valid?
  end

  def test_validates_uniqueness_of_among_with_nested_hash_values_and_different_key_types
    define_hash_accessors_on_topic
    Topic.validates_uniqueness_of_among :metadata, :properties, compare_hash_keys_as_strings: true

    topic = Topic.new
    topic.metadata = { "author" => { "name" => "John", "email" => "john@example.com" }, "year" => 2023 }
    topic.properties = { year: 2023, author: { name: "John", email: "john@example.com" } }

    assert_predicate topic, :invalid?
    assert_equal ["has already been taken among properties"], topic.errors[:metadata]
    assert_equal ["has already been taken among metadata"], topic.errors[:properties]
  end
end
