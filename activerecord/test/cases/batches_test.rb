require 'cases/helper'
require 'models/post'
require 'models/subscriber'

class EachTest < ActiveRecord::TestCase
  fixtures :posts, :subscribers

  def setup
    @posts = Post.order("id asc")
    @total = Post.count
    Post.count('id') # preheat arel's table cache
  end

  def test_in_batches_should_not_execute_any_query
    assert_no_queries do
      assert_kind_of ActiveRecord::Batches::BatchEnumerator, Post.in_batches(of: 2)
    end
  end

  def test_in_batches_should_yield_relation_if_block_given
    assert_queries(6) do
      Post.in_batches(of: 2) do |relation|
        assert_kind_of ActiveRecord::Relation, relation
      end
    end
  end

  def test_in_batches_should_be_enumerable_if_no_block_given
    assert_queries(6) do
      Post.in_batches(of: 2).each do |relation|
        assert_kind_of ActiveRecord::Relation, relation
      end
    end
  end

  def test_in_batches_each_record_should_yield_record_if_block_is_given
    assert_queries(6) do
      Post.in_batches(of: 2).each_record do |post|
        assert post.title.present?
        assert_kind_of Post, post
      end
    end
  end

  def test_in_batches_each_record_should_return_enumerator_if_no_block_given
    assert_queries(6) do
      Post.in_batches(of: 2).each_record.with_index do |post, i|
        assert post.title.present?
        assert_kind_of Post, post
      end
    end
  end

  def test_in_batches_each_record_should_be_ordered_by_id
    ids = Post.order('id ASC').pluck(:id)
    assert_queries(6) do
      Post.in_batches(of: 2).each_record.with_index do |post, i|
        assert_equal ids[i], post.id
      end
    end
  end

  def test_in_batches_update_all_affect_all_records
    assert_queries(6 + 6) do # 6 selects, 6 updates
      Post.in_batches(of: 2).update_all(title: "updated-title")
    end
    assert_equal Post.all.pluck(:title), ["updated-title"] * Post.count
  end

  def test_in_batches_delete_all_should_not_delete_records_in_other_batches
    not_deleted_count = Post.where('id <= 2').count
    Post.where('id > 2').in_batches(of: 2).delete_all
    assert_equal 0, Post.where('id > 2').count
    assert_equal not_deleted_count, Post.count
  end

  def test_in_batches_should_not_be_loaded
    Post.in_batches(of: 1) do |relation|
      assert_not relation.loaded?
    end

    Post.in_batches(of: 1, load: false) do |relation|
      assert_not relation.loaded?
    end
  end

  def test_in_batches_should_be_loaded
    Post.in_batches(of: 1, load: true) do |relation|
      assert relation.loaded?
    end
  end

  def test_in_batches_if_not_loaded_executes_more_queries
    assert_queries(@total + 1) do
      Post.in_batches(of: 1, load: false) do |relation|
        assert_not relation.loaded?
      end
    end
  end

  def test_in_batches_should_return_relations
    assert_queries(@total + 1) do
      Post.in_batches(of: 1) do |relation|
        assert_kind_of ActiveRecord::Relation, relation
      end
    end
  end

  def test_in_batches_should_start_from_the_start_option
    post = Post.order('id ASC').where('id >= ?', 2).first
    assert_queries(2) do
      relation = Post.in_batches(of: 1, begin_at: 2).first
      assert_equal post, relation.first
    end
  end

  def test_in_batches_should_end_at_the_end_option
    post = Post.order('id DESC').where('id <= ?', 5).first
    assert_queries(7) do
      relation = Post.in_batches(of: 1, end_at: 5, load: true).reverse_each.first
      assert_equal post, relation.last
    end
  end

  def test_in_batches_shouldnt_execute_query_unless_needed
    assert_queries(2) do
      Post.in_batches(of: @total) { |relation| assert_kind_of ActiveRecord::Relation, relation }
    end

    assert_queries(1) do
      Post.in_batches(of: @total + 1) { |relation| assert_kind_of ActiveRecord::Relation, relation }
    end
  end

  def test_in_batches_should_quote_batch_order
    c = Post.connection
    assert_sql(/ORDER BY #{c.quote_table_name('posts')}.#{c.quote_column_name('id')}/) do
      Post.in_batches(of: 1) do |relation|
        assert_kind_of ActiveRecord::Relation, relation
        assert_kind_of Post, relation.first
      end
    end
  end

  def test_in_batches_should_not_use_records_after_yielding_them_in_case_original_array_is_modified
    not_a_post = "not a post"
    def not_a_post.id
      raise StandardError.new("not_a_post had #id called on it")
    end

    assert_nothing_raised do
      Post.in_batches(of: 1) do |relation|
        assert_kind_of ActiveRecord::Relation, relation
        assert_kind_of Post, relation.first

        relation = [not_a_post] * relation.count
      end
    end
  end

  def test_in_batches_should_not_ignore_default_scope_without_order_statements
    special_posts_ids = SpecialPostWithDefaultScope.all.map(&:id).sort
    posts = []
    SpecialPostWithDefaultScope.in_batches do |relation|
      posts.concat(relation)
    end
    assert_equal special_posts_ids, posts.map(&:id)
  end

  def test_in_batches_should_not_modify_passed_options
    assert_nothing_raised do
      Post.in_batches({ of: 42, begin_at: 1 }.freeze){}
    end
  end

  def test_in_batches_should_use_any_column_as_primary_key
    nick_order_subscribers = Subscriber.order('nick asc')
    start_nick = nick_order_subscribers.second.nick

    subscribers = []
    Subscriber.in_batches(of: 1, begin_at: start_nick) do |relation|
      subscribers.concat(relation)
    end

    assert_equal nick_order_subscribers[1..-1].map(&:id), subscribers.map(&:id)
  end

  def test_in_batches_should_use_any_column_as_primary_key_when_start_is_not_specified
    assert_queries(Subscriber.count + 1) do
      Subscriber.in_batches(of: 1, load: true) do |relation|
        assert_kind_of ActiveRecord::Relation, relation
        assert_kind_of Subscriber, relation.first
      end
    end
  end

  def test_in_batches_should_return_an_enumerator
    enum = nil
    assert_no_queries do
      enum = Post.in_batches(of: 1)
    end
    assert_queries(4) do
      enum.first(4) do |relation|
        assert_kind_of ActiveRecord::Relation, relation
        assert_kind_of Post, relation.first
      end
    end
  end

  def test_in_batches_relations_should_not_overlap_with_each_other
    seen_posts = []
    Post.in_batches(of: 2, load: true) do |relation|
      relation.to_a.each do |post|
        assert_not seen_posts.include?(post)
        seen_posts << post
      end
    end
  end

  def test_in_batches_relations_with_condition_should_not_overlap_with_each_other
    seen_posts = []
    author_id = Post.first.author_id
    posts_by_author = Post.where(author_id: author_id)
    Post.in_batches(of: 2) do |batch|
      seen_posts += batch.where(author_id: author_id)
    end

    assert_equal posts_by_author.pluck(:id).sort, seen_posts.map(&:id).sort
  end

  def test_in_batches_relations_update_all_should_not_affect_matching_records_in_other_batches
    Post.update_all(author_id: 0)
    person = Post.last
    person.update_attributes(author_id: 1)

    Post.in_batches(of: 2) do |batch|
      batch.where('author_id >= 1').update_all('author_id = author_id + 1')
    end
    assert_equal 2, person.reload.author_id # incremented only once
  end

  def test_find_each_deprecated
    assert_deprecated do
      Post.find_each do |post|
        assert_kind_of Post, post
      end
    end
  end

  def test_find_in_batches_deprecated
    assert_deprecated do
      Post.find_in_batches do |batch|
        assert_kind_of Array, batch
        assert_kind_of Post, batch.first
      end
    end
  end
end
