require "cases/helper"
require 'models/post'
require 'models/topic'
require 'models/comment'
require 'models/reply'
require 'models/author'
require 'models/developer'

class NamedScopeTest < ActiveRecord::TestCase
  fixtures :posts, :authors, :topics, :comments, :author_addresses

  def test_implements_enumerable
    assert !Topic.find(:all).empty?

    assert_equal Topic.find(:all),   Topic.base
    assert_equal Topic.find(:all),   Topic.base.to_a
    assert_equal Topic.find(:first), Topic.base.first
    assert_equal Topic.find(:all),   Topic.base.each { |i| i }
  end

  def test_found_items_are_cached
    Topic.columns
    all_posts = Topic.base

    assert_queries(1) do
      all_posts.collect
      all_posts.collect
    end
  end

  def test_reload_expires_cache_of_found_items
    all_posts = Topic.base
    all_posts.inspect

    new_post = Topic.create!
    assert !all_posts.include?(new_post)
    assert all_posts.reload.include?(new_post)
  end

  def test_delegates_finds_and_calculations_to_the_base_class
    assert !Topic.find(:all).empty?

    assert_equal Topic.find(:all),               Topic.base.find(:all)
    assert_equal Topic.find(:first),             Topic.base.find(:first)
    assert_equal Topic.count,                    Topic.base.count
    assert_equal Topic.average(:replies_count), Topic.base.average(:replies_count)
  end

  def test_scope_should_respond_to_own_methods_and_methods_of_the_proxy
    assert Topic.approved.respond_to?(:proxy_found)
    assert Topic.approved.respond_to?(:count)
    assert Topic.approved.respond_to?(:length)
  end

  def test_respond_to_respects_include_private_parameter
    assert !Topic.approved.respond_to?(:load_found)
    assert Topic.approved.respond_to?(:load_found, true)
  end

  def test_subclasses_inherit_scopes
    assert Topic.scopes.include?(:base)

    assert Reply.scopes.include?(:base)
    assert_equal Reply.find(:all), Reply.base
  end

  def test_scopes_with_options_limit_finds_to_those_matching_the_criteria_specified
    assert !Topic.find(:all, :conditions => {:approved => true}).empty?

    assert_equal Topic.find(:all, :conditions => {:approved => true}), Topic.approved
    assert_equal Topic.count(:conditions => {:approved => true}), Topic.approved.count
  end

  def test_scopes_with_string_name_can_be_composed
    # NOTE that scopes defined with a string as a name worked on their own
    # but when called on another scope the other scope was completely replaced
    assert_equal Topic.replied.approved, Topic.replied.approved_as_string
  end

  def test_scopes_can_be_specified_with_deep_hash_conditions
    assert_equal Topic.replied.approved, Topic.replied.approved_as_hash_condition
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

  def test_scopes_with_joins
    address = author_addresses(:david_address)
    posts_with_authors_at_address = Post.find(
      :all, :joins => 'JOIN authors ON authors.id = posts.author_id',
      :conditions => [ 'authors.author_address_id = ?', address.id ]
    )
    assert_equal posts_with_authors_at_address, Post.with_authors_at_address(address)
  end

  def test_scopes_with_joins_respects_custom_select
    address = author_addresses(:david_address)
    posts_with_authors_at_address_titles = Post.find(:all,
      :select => 'title',
      :joins => 'JOIN authors ON authors.id = posts.author_id',
      :conditions => [ 'authors.author_address_id = ?', address.id ]
    )
    assert_equal posts_with_authors_at_address_titles, Post.with_authors_at_address(address).find(:all, :select => 'title')
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
    assert_not_equal Comment.containing_the_letter_e, authors(:david).comments
    assert !Comment.containing_the_letter_e.empty?

    assert_equal authors(:david).comments & Comment.containing_the_letter_e, authors(:david).comments.containing_the_letter_e
  end

  def test_named_scopes_honor_current_scopes_from_when_defined
    assert !Post.ranked_by_comments.limit(5).empty?
    assert !authors(:david).posts.ranked_by_comments.limit(5).empty?
    assert_not_equal Post.ranked_by_comments.limit(5), authors(:david).posts.ranked_by_comments.limit(5)
    assert_not_equal Post.top(5), authors(:david).posts.top(5)
    assert_equal authors(:david).posts.ranked_by_comments.limit(5), authors(:david).posts.top(5)
    assert_equal Post.ranked_by_comments.limit(5), Post.top(5)
  end

  def test_active_records_have_scope_named__all__
    assert !Topic.find(:all).empty?

    assert_equal Topic.find(:all), Topic.base
  end

  def test_active_records_have_scope_named__scoped__
    assert !Topic.find(:all, scope = {:conditions => "content LIKE '%Have%'"}).empty?

    assert_equal Topic.find(:all, scope), Topic.scoped(scope)
  end

  def test_proxy_options
    expected_proxy_options = { :conditions => { :approved => true } }
    assert_equal expected_proxy_options, Topic.approved.proxy_options
  end

  def test_first_and_last_should_support_find_options
    assert_equal Topic.base.first(:order => 'title'), Topic.base.find(:first, :order => 'title')
    assert_equal Topic.base.last(:order => 'title'), Topic.base.find(:last, :order => 'title')
  end

  def test_first_and_last_should_allow_integers_for_limit
    assert_equal Topic.base.first(2), Topic.base.to_a.first(2)
    assert_equal Topic.base.last(2), Topic.base.to_a.last(2)
  end

  def test_first_and_last_should_not_use_query_when_results_are_loaded
    topics = Topic.base
    topics.reload # force load
    assert_no_queries do
      topics.first
      topics.last
    end
  end

  def test_first_and_last_find_options_should_use_query_when_results_are_loaded
    topics = Topic.base
    topics.reload # force load
    assert_queries(2) do
      topics.first(:order => 'title')
      topics.last(:order => 'title')
    end
  end

  def test_empty_should_not_load_results
    topics = Topic.base
    assert_queries(2) do
      topics.empty?  # use count query
      topics.collect # force load
      topics.empty?  # use loaded (no query)
    end
  end

  def test_any_should_not_load_results
    topics = Topic.base
    assert_queries(2) do
      topics.any?    # use count query
      topics.collect # force load
      topics.any?    # use loaded (no query)
    end
  end

  def test_any_should_call_proxy_found_if_using_a_block
    topics = Topic.base
    assert_queries(1) do
      topics.expects(:empty?).never
      topics.any? { true }
    end
  end

  def test_any_should_not_fire_query_if_named_scope_loaded
    topics = Topic.base
    topics.collect # force load
    assert_no_queries { assert topics.any? }
  end

  def test_should_build_with_proxy_options
    topic = Topic.approved.build({})
    assert topic.approved
  end

  def test_should_build_new_with_proxy_options
    topic = Topic.approved.new
    assert topic.approved
  end

  def test_should_create_with_proxy_options
    topic = Topic.approved.create({})
    assert topic.approved
  end

  def test_should_create_with_bang_with_proxy_options
    topic = Topic.approved.create!({})
    assert topic.approved
  end
  
  def test_should_build_with_proxy_options_chained
    topic = Topic.approved.by_lifo.build({})
    assert topic.approved
    assert_equal 'lifo', topic.author_name
  end

  def test_find_all_should_behave_like_select
    assert_equal Topic.base.select(&:approved), Topic.base.find_all(&:approved)
  end

  def test_rand_should_select_a_random_object_from_proxy
    assert Topic.approved.rand.is_a?(Topic)
  end

  def test_should_use_where_in_query_for_named_scope
    assert_equal Developer.find_all_by_name('Jamis').to_set, Developer.find_all_by_id(Developer.jamises).to_set
  end

  def test_size_should_use_count_when_results_are_not_loaded
    topics = Topic.base
    assert_queries(1) do
      assert_sql(/COUNT/i) { topics.size }
    end
  end

  def test_size_should_use_length_when_results_are_loaded
    topics = Topic.base
    topics.reload # force load
    assert_no_queries do
      topics.size # use loaded (no query)
    end
  end

  def test_chaining_with_duplicate_joins
    join = "INNER JOIN comments ON comments.post_id = posts.id"
    post = Post.find(1)
    assert_equal post.comments.size, Post.scoped(:joins => join).scoped(:joins => join, :conditions => "posts.id = #{post.id}").size
  end

  def test_chanining_should_use_latest_conditions_when_creating
    post1 = Topic.rejected.approved.new
    assert post1.approved?

    post2 = Topic.approved.rejected.new
    assert ! post2.approved?
  end

  def test_chanining_should_use_latest_conditions_when_searching
    # Normal hash conditions
    assert_equal Topic.all(:conditions => {:approved => true}), Topic.rejected.approved.all
    assert_equal Topic.all(:conditions => {:approved => false}), Topic.approved.rejected.all

    # Nested hash conditions with same keys
    assert_equal [posts(:sti_comments)], Post.with_special_comments.with_very_special_comments.all

    # Nested hash conditions with different keys
    assert_equal [posts(:sti_comments)], Post.with_special_comments.with_post(4).all.uniq
  end
end

class DynamicScopeMatchTest < ActiveRecord::TestCase  
  def test_scoped_by_no_match
    assert_nil ActiveRecord::DynamicScopeMatch.match("not_scoped_at_all")
  end

  def test_scoped_by
    match = ActiveRecord::DynamicScopeMatch.match("scoped_by_age_and_sex_and_location")
    assert_not_nil match
    assert match.scope?
    assert_equal %w(age sex location), match.attribute_names
  end
end

class DynamicScopeTest < ActiveRecord::TestCase
  def test_dynamic_scope
    assert_equal Post.scoped_by_author_id(1).find(1), Post.find(1)
    assert_equal Post.scoped_by_author_id_and_title(1, "Welcome to the weblog").first, Post.find(:first, :conditions => { :author_id => 1, :title => "Welcome to the weblog"})
  end
end
