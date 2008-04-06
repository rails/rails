require "cases/helper"
require 'models/topic'

class FinderRespondToTest < ActiveRecord::TestCase

  fixtures :topics

  def test_should_preserve_normal_respond_to_behaviour_and_respond_to_newly_added_method
    class << Topic; self; end.send(:define_method, :method_added_for_finder_respond_to_test) { }
    assert Topic.respond_to?(:method_added_for_finder_respond_to_test)
  ensure
    class << Topic; self; end.send(:remove_method, :method_added_for_finder_respond_to_test)
  end

  def test_should_preserve_normal_respond_to_behaviour_and_respond_to_standard_object_method
    assert Topic.respond_to?(:to_s)
  end

  def test_should_respond_to_find_by_one_attribute_before_caching
    ensure_topic_method_is_not_cached(:find_by_title)
    assert Topic.respond_to?(:find_by_title)
  end

  def test_should_respond_to_find_all_by_one_attribute
    ensure_topic_method_is_not_cached(:find_all_by_title)
    assert Topic.respond_to?(:find_all_by_title)
  end

  def test_should_respond_to_find_all_by_two_attributes
    ensure_topic_method_is_not_cached(:find_all_by_title_and_author_name)
    assert Topic.respond_to?(:find_all_by_title_and_author_name)
  end

  def test_should_respond_to_find_by_two_attributes
    ensure_topic_method_is_not_cached(:find_by_title_and_author_name)
    assert Topic.respond_to?(:find_by_title_and_author_name)
  end

  def test_should_respond_to_find_or_initialize_from_one_attribute
    ensure_topic_method_is_not_cached(:find_or_initialize_by_title)
    assert Topic.respond_to?(:find_or_initialize_by_title)
  end

  def test_should_respond_to_find_or_initialize_from_two_attributes
    ensure_topic_method_is_not_cached(:find_or_initialize_by_title_and_author_name)
    assert Topic.respond_to?(:find_or_initialize_by_title_and_author_name)
  end

  def test_should_respond_to_find_or_create_from_one_attribute
    ensure_topic_method_is_not_cached(:find_or_create_by_title)
    assert Topic.respond_to?(:find_or_create_by_title)
  end

  def test_should_respond_to_find_or_create_from_two_attributes
    ensure_topic_method_is_not_cached(:find_or_create_by_title_and_author_name)
    assert Topic.respond_to?(:find_or_create_by_title_and_author_name)
  end

  def test_should_not_respond_to_find_by_one_missing_attribute
    assert !Topic.respond_to?(:find_by_undertitle)
  end

  def test_should_not_respond_to_find_by_invalid_method_syntax
    assert !Topic.respond_to?(:fail_to_find_by_title)
    assert !Topic.respond_to?(:find_by_title?)
    assert !Topic.respond_to?(:fail_to_find_or_create_by_title)
    assert !Topic.respond_to?(:find_or_create_by_title?)
  end

  private

  def ensure_topic_method_is_not_cached(method_id)
    class << Topic; self; end.send(:remove_method, method_id) if Topic.public_methods.any? { |m| m.to_s == method_id.to_s }
  end

end