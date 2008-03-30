require "cases/helper"
require 'models/post'
require 'models/topic'
require 'models/comment'
require 'models/reply'
require 'models/author'

class NamedScopeTest < ActiveRecord::TestCase
  fixtures :posts, :authors, :topics

  def test_implements_enumerable
    assert !Topic.find(:all).empty?

    assert_equal Topic.find(:all),   Topic.all
    assert_equal Topic.find(:all),   Topic.all.to_a
    assert_equal Topic.find(:first), Topic.all.first
    assert_equal Topic.find(:all),   Topic.all.each { |i| i }
  end

  def test_found_items_are_cached
    Topic.columns
    all_posts = Topic.all

    assert_queries(1) do
      all_posts.collect
      all_posts.collect
    end
  end

  def test_reload_expires_cache_of_found_items
    all_posts = Topic.all
    all_posts.inspect

    new_post = Topic.create!
    assert !all_posts.include?(new_post)
    assert all_posts.reload.include?(new_post)
  end

  def test_delegates_finds_and_calculations_to_the_base_class
    assert !Topic.find(:all).empty?

    assert_equal Topic.find(:all),               Topic.all.find(:all)
    assert_equal Topic.find(:first),             Topic.all.find(:first)
    assert_equal Topic.count,                    Topic.all.count
    assert_equal Topic.average(:replies_count), Topic.all.average(:replies_count)
  end

  def test_subclasses_inherit_scopes
    assert Topic.scopes.include?(:all)

    assert Reply.scopes.include?(:all)
    assert_equal Reply.find(:all), Reply.all
  end

  def test_scopes_with_options_limit_finds_to_those_matching_the_criteria_specified
    assert !Topic.find(:all, :conditions => {:approved => true}).empty?

    assert_equal Topic.find(:all, :conditions => {:approved => true}), Topic.approved
    assert_equal Topic.count(:conditions => {:approved => true}), Topic.approved.count
  end

  def test_scopes_are_composable
    assert_equal (approved = Topic.find(:all, :conditions => {:approved => true})), Topic.approved
    assert_equal (replied = Topic.find(:all, :conditions => 'replies_count > 0')), Topic.replied
    assert !(approved == replied)
    assert !(approved & replied).empty?

    assert_equal approved & replied, Topic.approved.replied
  end

  def test_procedural_scopes
    topics_written_before_the_third = Topic.find(:all, :conditions => ['written_on < ?', topics(:third).written_on])
    topics_written_before_the_second = Topic.find(:all, :conditions => ['written_on < ?', topics(:second).written_on])
    assert_not_equal topics_written_before_the_second, topics_written_before_the_third

    assert_equal topics_written_before_the_third, Topic.written_before(topics(:third).written_on)
    assert_equal topics_written_before_the_second, Topic.written_before(topics(:second).written_on)
  end

  def test_extensions
    assert_equal 1, Topic.anonymous_extension.one
    assert_equal 2, Topic.named_extension.two
  end

  def test_multiple_extensions
    assert_equal 2, Topic.multiple_extensions.extension_two
    assert_equal 1, Topic.multiple_extensions.extension_one
  end

  def test_has_many_associations_have_access_to_named_scopes
    assert_not_equal Post.containing_the_letter_a, authors(:david).posts
    assert !Post.containing_the_letter_a.empty?

    assert_equal authors(:david).posts & Post.containing_the_letter_a, authors(:david).posts.containing_the_letter_a
  end

  def test_has_many_through_associations_have_access_to_named_scopes
    assert_not_equal Comment.containing_the_letter_e, authors(:david).posts
    assert !Comment.containing_the_letter_e.empty?

    assert_equal authors(:david).comments & Comment.containing_the_letter_e, authors(:david).comments.containing_the_letter_e
  end

  def test_active_records_have_scope_named__all__
    assert !Topic.find(:all).empty?

    assert_equal Topic.find(:all), Topic.all
  end

  def test_active_records_have_scope_named__scoped__
    assert !Topic.find(:all, scope = {:conditions => "content LIKE '%Have%'"}).empty?

    assert_equal Topic.find(:all, scope), Topic.scoped(scope)
  end
end
