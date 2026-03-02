# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/subscriber"
require "models/developer"
require "models/cpk"

class EachTest < ActiveRecord::TestCase
  fixtures :posts, :subscribers, :developers, :cpk_orders

  def setup
    @posts = Post.order("id asc")
    @total = Post.count
    Post.count("id") # preheat arel's table cache
  end

  def test_each_should_execute_one_query_per_batch
    assert_queries_count(@total + 1) do
      Post.find_each(batch_size: 1) do |post|
        assert_kind_of Post, post
      end
    end
  end

  def test_each_should_not_return_query_chain_and_execute_only_one_query
    assert_queries_count(1) do
      result = Post.find_each(batch_size: 100000) { }
      assert_nil result
    end
  end

  def test_each_should_return_an_enumerator_if_no_block_is_present
    assert_queries_count(1) do
      Post.find_each(batch_size: 100000).with_index do |post, index|
        assert_kind_of Post, post
        assert_kind_of Integer, index
      end
    end
  end

  def test_each_should_return_a_sized_enumerator
    assert_equal 11, Post.find_each(batch_size: 1).size
    assert_equal 5, Post.find_each(batch_size:  2, start: 7).size
    assert_equal 11, Post.find_each(batch_size: 10_000).size
  end

  def test_each_enumerator_should_execute_one_query_per_batch
    assert_queries_count(@total + 1) do
      Post.find_each(batch_size: 1).with_index do |post, index|
        assert_kind_of Post, post
        assert_kind_of Integer, index
      end
    end
  end

  def test_each_should_raise_if_select_is_set_without_id
    assert_raise(ArgumentError) do
      Post.select(:title).find_each(batch_size: 1) { |post|
        flunk "should not call this block"
      }
    end
  end

  def test_each_should_execute_if_id_is_in_select
    assert_queries_count(6) do
      Post.select("id, title, type").find_each(batch_size: 2) do |post|
        assert_kind_of Post, post
      end
    end
  end

  test "find_each should honor limit if passed a block" do
    limit = @total - 1
    total = 0

    Post.limit(limit).find_each do |post|
      total += 1
    end

    assert_equal limit, total
  end

  test "find_each should honor limit if no block is passed" do
    limit = @total - 1
    total = 0

    Post.limit(limit).find_each.each do |post|
      total += 1
    end

    assert_equal limit, total
  end

  def test_warn_if_order_scope_is_set
    previous_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = ActiveSupport::Logger.new(nil)

    assert_called(ActiveRecord::Base.logger, :warn) do
      Post.order("title").find_each { |post| post }
    end
  ensure
    ActiveRecord::Base.logger = previous_logger
  end

  def test_logger_not_required
    previous_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = nil
    assert_nothing_raised do
      Post.order("comments_count DESC").find_each { |post| post }
    end
  ensure
    ActiveRecord::Base.logger = previous_logger
  end

  def test_find_in_batches_should_return_batches
    assert_queries_count(@total + 1) do
      Post.find_in_batches(batch_size: 1) do |batch|
        assert_kind_of Array, batch
        assert_kind_of Post, batch.first
      end
    end
  end

  def test_find_in_batches_should_start_from_the_start_option
    assert_queries_count(@total) do
      Post.find_in_batches(batch_size: 1, start: 2) do |batch|
        assert_kind_of Array, batch
        assert_kind_of Post, batch.first
      end
    end
  end

  def test_find_in_batches_should_end_at_the_finish_option
    assert_queries_count(6) do
      Post.find_in_batches(batch_size: 1, finish: 5) do |batch|
        assert_kind_of Array, batch
        assert_kind_of Post, batch.first
      end
    end
  end

  def test_find_in_batches_shouldnt_execute_query_unless_needed
    assert_queries_count(2) do
      Post.find_in_batches(batch_size: @total) { |batch| assert_kind_of Array, batch }
    end

    assert_queries_count(1) do
      Post.find_in_batches(batch_size: @total + 1) { |batch| assert_kind_of Array, batch }
    end
  end

  def test_find_in_batches_should_quote_batch_order
    assert_queries_match(/ORDER BY #{Regexp.escape(quote_table_name("posts.id"))}/i) do
      Post.find_in_batches(batch_size: 1) do |batch|
        assert_kind_of Array, batch
        assert_kind_of Post, batch.first
      end
    end
  end

  def test_find_in_batches_should_quote_batch_order_with_desc_order
    assert_queries_match(/ORDER BY #{Regexp.escape(quote_table_name("posts.id"))} DESC/) do
      Post.find_in_batches(batch_size: 1, order: :desc) do |batch|
        assert_kind_of Array, batch
        assert_kind_of Post, batch.first
      end
    end
  end

  def test_each_should_raise_if_order_is_invalid
    assert_raise(ArgumentError) do
      Post.select(:title).find_each(batch_size: 1, order: :invalid) { |post|
        flunk "should not call this block"
      }
    end
  end

  def test_in_batches_without_block_should_raise_if_order_is_invalid
    assert_raise(ArgumentError) do
      Post.select(:title).in_batches(order: :invalid)
    end
  end

  def test_find_in_batches_should_not_use_records_after_yielding_them_in_case_original_array_is_modified
    not_a_post = +"not a post"
    def not_a_post.id; end
    not_a_post.stub(:id, -> { raise StandardError.new("not_a_post had #id called on it") }) do
      assert_nothing_raised do
        Post.find_in_batches(batch_size: 1) do |batch|
          assert_kind_of Array, batch
          assert_kind_of Post, batch.first

          batch.map! { not_a_post }
        end
      end
    end
  end

  def test_find_in_batches_should_ignore_the_order_default_scope
    # First post is with title scope
    first_post = PostWithDefaultScope.first
    posts = []
    PostWithDefaultScope.find_in_batches  do |batch|
      posts.concat(batch)
    end
    # posts.first will be ordered using id only. Title order scope should not apply here
    assert_not_equal first_post, posts.first
    assert_equal posts(:welcome).id, posts.first.id
  end

  def test_find_in_batches_should_error_on_ignore_the_order
    assert_raise(ArgumentError) do
      PostWithDefaultScope.find_in_batches(error_on_ignore: true) { }
    end
  end

  def test_find_in_batches_should_not_error_if_config_overridden
    # Set the config option which will be overridden
    prev = ActiveRecord.error_on_ignored_order
    ActiveRecord.error_on_ignored_order = true
    assert_nothing_raised do
      PostWithDefaultScope.find_in_batches(error_on_ignore: false) { }
    end
  ensure
    # Set back to default
    ActiveRecord.error_on_ignored_order = prev
  end

  def test_find_in_batches_should_error_on_config_specified_to_error
    # Set the config option
    prev = ActiveRecord.error_on_ignored_order
    ActiveRecord.error_on_ignored_order = true
    assert_raise(ArgumentError) do
      PostWithDefaultScope.find_in_batches() { }
    end
  ensure
    # Set back to default
    ActiveRecord.error_on_ignored_order = prev
  end

  def test_find_in_batches_should_not_error_by_default
    assert_nothing_raised do
      PostWithDefaultScope.find_in_batches() { }
    end
  end

  def test_find_in_batches_should_not_ignore_the_default_scope_if_it_is_other_then_order
    default_scope = SpecialPostWithDefaultScope.all
    posts = []
    SpecialPostWithDefaultScope.find_in_batches do |batch|
      posts.concat(batch)
    end
    assert_equal default_scope.pluck(:id).sort, posts.map(&:id).sort
  end

  def test_find_in_batches_should_use_any_column_as_primary_key
    nick_order_subscribers = Subscriber.order("nick asc")
    start_nick = nick_order_subscribers.second.nick

    subscribers = []
    Subscriber.find_in_batches(batch_size: 1, start: start_nick) do |batch|
      subscribers.concat(batch)
    end

    assert_equal nick_order_subscribers[1..-1].map(&:id), subscribers.map(&:id)
  end

  def test_find_in_batches_should_use_any_column_as_primary_key_when_start_is_not_specified
    assert_queries_count(Subscriber.count + 1) do
      Subscriber.find_in_batches(batch_size: 1) do |batch|
        assert_kind_of Array, batch
        assert_kind_of Subscriber, batch.first
      end
    end
  end

  def test_find_in_batches_should_return_an_enumerator
    enum = nil
    assert_no_queries do
      enum = Post.find_in_batches(batch_size: 1)
    end
    assert_queries_count(4) do
      enum.first(4) do |batch|
        assert_kind_of Array, batch
        assert_kind_of Post, batch.first
      end
    end
  end

  test "find_in_batches should honor limit if passed a block" do
    limit = @total - 1
    total = 0

    Post.limit(limit).find_in_batches do |batch|
      total += batch.size
    end

    assert_equal limit, total
  end

  test "find_in_batches should honor limit if no block is passed" do
    limit = @total - 1
    total = 0

    Post.limit(limit).find_in_batches.each do |batch|
      total += batch.size
    end

    assert_equal limit, total
  end

  def test_in_batches_should_not_execute_any_query
    assert_no_queries do
      assert_kind_of ActiveRecord::Batches::BatchEnumerator, Post.in_batches(of: 2)
    end
  end

  def test_in_batches_should_error_on_ignore_the_order
    assert_raise(ArgumentError, match: "Scoped order is ignored") do
      PostWithDefaultScope.in_batches(error_on_ignore: true) { }
    end

    assert_raise(ArgumentError, match: "Scoped order is ignored") do
      PostWithDefaultScope.in_batches(error_on_ignore: true).delete_all
    end
  end

  def test_in_batches_has_attribute_readers
    enumerator = Post.no_comments.in_batches(of: 2, start: 42, finish: 84)
    assert_equal Post.no_comments, enumerator.relation
    assert_equal 2, enumerator.batch_size
    assert_equal 42, enumerator.start
    assert_equal 84, enumerator.finish
  end

  def test_in_batches_should_yield_relation_if_block_given
    assert_queries_count(7) do
      Post.in_batches(of: 2) do |relation|
        assert_kind_of ActiveRecord::Relation, relation
      end
    end
  end

  def test_in_batches_should_be_enumerable_if_no_block_given
    assert_queries_count(7) do
      Post.in_batches(of: 2).each do |relation|
        assert_kind_of ActiveRecord::Relation, relation
      end
    end
  end

  def test_in_batches_each_record_should_yield_record_if_block_is_given
    assert_queries_count(6) do
      Post.in_batches(of: 2).each_record do |post|
        assert_predicate post.title, :present?
        assert_kind_of Post, post
      end
    end
  end

  def test_in_batches_each_record_should_return_enumerator_if_no_block_given
    assert_queries_count(6) do
      Post.in_batches(of: 2).each_record.with_index do |post, i|
        assert_predicate post.title, :present?
        assert_kind_of Post, post
      end
    end
  end

  def test_in_batches_each_record_should_be_ordered_by_id
    ids = Post.order("id ASC").pluck(:id)
    assert_queries_count(6) do
      Post.in_batches(of: 2).each_record.with_index do |post, i|
        assert_equal ids[i], post.id
      end
    end
  end

  def test_in_batches_update_all_affect_all_records
    assert_queries_count(7 + 6) do # 7 selects, 6 updates
      Post.in_batches(of: 2).update_all(title: "updated-title")
    end
    assert_equal ["updated-title"] * Post.count, Post.all.pluck(:title)
  end

  def test_in_batches_update_all_returns_rows_affected
    assert_equal 11, Post.in_batches(of: 2).update_all(title: "updated-title")
  end

  def test_in_batches_update_all_returns_zero_when_no_batches
    assert_equal 0, Post.where("1=0").in_batches(of: 2).update_all(title: "updated-title")
  end

  def test_in_batches_touch_all_affect_all_records
    time = Time.new(2000, 1, 1, 0, 0, 0)
    assert_queries_count(7 + 6) do # 7 selects, 6 updates
      Developer.in_batches(of: 2).touch_all(time: time)
    end
    assert_equal [time] * Developer.count, Developer.all.pluck(:updated_at)
  end

  def test_in_batches_touch_all_returns_rows_affected
    assert_equal 11, Developer.in_batches(of: 2).touch_all
  end

  def test_in_batches_touch_all_returns_zero_when_no_batches
    assert_equal 0, Developer.where("1=0").in_batches(of: 2).touch_all
  end

  def test_in_batches_delete_all_should_not_delete_records_in_other_batches
    not_deleted_count = Post.where("id <= 2").count
    Post.where("id > 2").in_batches(of: 2).delete_all
    assert_equal 0, Post.where("id > 2").count
    assert_equal not_deleted_count, Post.count
  end

  def test_in_batches_delete_all_returns_rows_affected
    assert_equal 11, Post.in_batches(of: 2).delete_all
  end

  def test_in_batches_delete_all_returns_zero_when_no_batches
    assert_equal 0, Post.where("1=0").in_batches(of: 2).delete_all
  end

  def test_in_batches_destroy_all_should_not_destroy_records_in_other_batches
    not_destroyed_count = Post.where("id <= 2").count
    Post.where("id > 2").in_batches(of: 2).destroy_all
    assert_equal 0, Post.where("id > 2").count
    assert_equal not_destroyed_count, Post.count
  end

  def test_in_batches_destroy_all_returns_rows_affected
    # 1 records is not destroyed because of the callback.
    assert_equal 10, PostWithDestroyCallback.in_batches(of: 2).destroy_all
  end

  def test_in_batches_destroy_all_returns_zero_when_no_batches
    assert_equal 0, Post.where("1=0").in_batches(of: 2).destroy_all
  end

  def test_in_batches_should_not_be_loaded
    Post.in_batches(of: 1) do |relation|
      assert_not_predicate relation, :loaded?
    end

    Post.in_batches(of: 1, load: false) do |relation|
      assert_not_predicate relation, :loaded?
    end
  end

  def test_in_batches_should_be_loaded
    Post.in_batches(of: 1, load: true) do |relation|
      assert_predicate relation, :loaded?
    end
  end

  def test_in_batches_if_not_loaded_executes_more_queries
    assert_queries_count(@total + 2) do
      Post.in_batches(of: 1, load: false) do |relation|
        assert_not_predicate relation, :loaded?
      end
    end
  end

  def test_in_batches_when_loaded_runs_no_queries
    posts = Post.all
    posts.load
    batch_count = 0
    last_id = posts.map(&:id).min
    assert_queries_count(0) do
      posts.in_batches(of: 1) do |relation|
        batch_count += 1
        assert_kind_of ActiveRecord::Relation, relation
        assert_operator last_id, :<=, relation.map(&:id).min
        last_id = relation.map(&:id).min
      end
    end

    assert_equal posts.size, batch_count
  end

  def test_in_batches_when_loaded_runs_no_queries_with_order_argument
    posts = Post.all.order(id: :asc)
    posts.load
    batch_count = 0
    last_id = posts.map(&:id).max
    assert_queries_count(0) do
      posts.in_batches(of: 1, order: :desc) do |relation|
        batch_count += 1
        assert_kind_of ActiveRecord::Relation, relation
        assert_operator last_id, :>=, relation.map(&:id).max
        last_id = relation.map(&:id).max
      end
    end

    assert_equal posts.size, batch_count
  end

  def test_in_batches_when_loaded_runs_no_queries_with_start_and_end_arguments
    posts = Post.all.order(id: :asc)
    posts.load
    batch_count = 0

    start_id = posts.map(&:id)[1]
    finish_id = posts.map(&:id)[-2]
    assert_queries_count(0) do
      posts.in_batches(of: 1, start: start_id, finish: finish_id) do |relation|
        batch_count += 1
        assert_kind_of ActiveRecord::Relation, relation
      end
    end

    assert_equal posts.size - 2, batch_count
  end

  def test_in_batches_when_loaded_runs_no_queries_with_start_and_end_arguments_and_reverse_order
    posts = Post.all.order(id: :asc)
    posts.load
    batch_count = 0

    start_id = posts.map(&:id)[-2]
    finish_id = posts.map(&:id)[1]
    assert_queries_count(0) do
      posts.in_batches(of: 1, start: start_id, finish: finish_id, order: :desc) do |relation|
        batch_count += 1
        assert_kind_of ActiveRecord::Relation, relation
      end
    end

    assert_equal posts.size - 2, batch_count
  end

  def test_in_batches_when_loaded_can_return_an_enum
    posts = Post.all
    posts.load
    batch_count = 0

    assert_queries_count(0) do
      posts.in_batches(of: 1).each do |relation|
        batch_count += 1
        assert_kind_of ActiveRecord::Relation, relation
      end
    end

    assert_equal posts.size, batch_count
  end

  def test_in_batches_when_loaded_runs_no_queries_when_batching_over_cpk_model
    incorrectly_sorted_orders = Cpk::Order.order(shop_id: :asc, id: :desc)
    incorrectly_sorted_orders.load

    correctly_sorted_orders = Cpk::Order.order(shop_id: :desc, id: :asc).to_a
    expected_orders = correctly_sorted_orders[1..-2]
    start_id = expected_orders.first.id
    finish_id = expected_orders.last.id
    orders = []

    assert_no_queries do
      incorrectly_sorted_orders.find_each(batch_size: 1, start: start_id, finish: finish_id, order: [:desc, :asc]) do |order|
        orders << order
      end
    end

    assert_equal expected_orders, orders
  end

  def test_in_batches_when_loaded_iterates_using_custom_column
    c = Post.lease_connection
    c.add_index(:posts, :title, unique: true)
    ActiveRecord::Base.schema_cache.clear!

    ordered_posts = Post.order(id: :desc)
    ordered_posts.load

    posts = []

    assert_no_queries do
      ordered_posts.in_batches(of: 1, cursor: :id, order: :desc).each_record do |post|
        posts << post
      end
    end

    assert_equal ordered_posts.to_a, posts
  ensure
    c.remove_index(:posts, :title)
  end

  def test_in_batches_should_return_relations
    assert_queries_count(@total + 2) do
      Post.in_batches(of: 1) do |relation|
        assert_kind_of ActiveRecord::Relation, relation
      end
    end
  end

  def test_in_batches_should_start_from_the_start_option
    post = Post.order("id ASC").where("id >= ?", 2).first
    assert_queries_count(2) do
      relation = Post.in_batches(of: 1, start: 2).first
      assert_equal post, relation.first
    end
  end

  def test_in_batches_should_end_at_the_finish_option
    post = Post.order("id DESC").where("id <= ?", 5).first
    assert_queries_count(8) do
      relation = Post.in_batches(of: 1, finish: 5, load: true).reverse_each.first
      assert_equal post, relation.last
    end
  end

  def test_in_batches_executes_range_queries_when_unconstrained
    quoted_posts_id = Regexp.escape(quote_table_name("posts.id"))

    relations = assert_queries_match(/ORDER BY #{quoted_posts_id} ASC LIMIT \S+ OFFSET \S+\z/i, count: 6) do
      assert_queries_match(/ORDER BY #{quoted_posts_id} ASC LIMIT \S+\z/i, count: 1) do
        Post.in_batches(of: 2).to_a
      end
    end

    assert_queries_match(/WHERE #{quoted_posts_id} > .+ AND #{quoted_posts_id} <= .+/i) do
      relations.each { |relation| assert_kind_of Post, relation.first }
    end
  end

  def test_in_batches_executes_in_queries_when_unconstrained_and_opted_out_of_ranges
    quoted_posts_id = Regexp.escape(quote_table_name("posts.id"))

    relations = assert_queries_match(/ORDER BY #{quoted_posts_id} ASC LIMIT \S+\z/i, count: 6) do
      Post.in_batches(of: 2, use_ranges: false).to_a
    end

    assert_queries_match(/#{quoted_posts_id} IN \(.+\)/i) do
      relations.each { |relation| assert_kind_of Post, relation.first }
    end
  end

  def test_in_batches_executes_in_queries_when_constrained
    quoted_posts_id = Regexp.escape(quote_table_name("posts.id"))

    relations = assert_queries_match(/ORDER BY #{quoted_posts_id} ASC LIMIT \S+\z/i, count: 3) do
      Post.where("id < ?", 5).in_batches(of: 2).to_a
    end

    assert_queries_match(/#{quoted_posts_id} IN \(.+\)/i) do
      relations.each { |relation| assert_kind_of Post, relation.first }
    end
  end

  def test_in_batches_executes_range_queries_when_constrained_and_opted_in_into_ranges
    quoted_posts_id = Regexp.escape(quote_table_name("posts.id"))

    relations = assert_queries_match(/ORDER BY #{quoted_posts_id} ASC LIMIT \S+ OFFSET \S+\z/i, count: 3) do
      assert_queries_match(/ORDER BY #{quoted_posts_id} ASC LIMIT \S+\z/i, count: 1) do
        Post.where("id < ?", 5).in_batches(of: 2, use_ranges: true).to_a
      end
    end

    assert_queries_match(/#{quoted_posts_id} > .+ AND #{quoted_posts_id} <= .+/i) do
      relations.each { |relation| assert_kind_of Post, relation.first }
    end
  end

  def test_in_batches_no_subqueries_for_whole_tables_batching
    quoted_posts_id = Regexp.escape(quote_table_name("posts.id"))
    assert_queries_match(/DELETE FROM #{Regexp.escape(quote_table_name("posts"))} WHERE #{quoted_posts_id} > .+ AND #{quoted_posts_id} <=/i) do
      Post.in_batches(of: 2).delete_all
    end
  end

  def test_in_batches_shouldnt_execute_query_unless_needed
    assert_queries_count(3) do
      Post.in_batches(of: @total) { |relation| assert_kind_of ActiveRecord::Relation, relation }
    end

    assert_queries_count(2) do
      Post.in_batches(of: @total + 1) { |relation| assert_kind_of ActiveRecord::Relation, relation }
    end
  end

  def test_in_batches_should_unscope_cursor_after_pluck
    all_ids = Post.limit(2).pluck(:id)
    found_ids = []
    # only a single clause on id (i.e. not 'id IN (?,?) AND id = ?', but only 'id = ?')
    assert_queries_match(/WHERE #{Regexp.escape(quote_table_name("posts.id"))} = \S+ LIMIT/) do
      Post.where(id: all_ids).in_batches(of: 1) do |relation|
        found_ids << relation.pick(:id)
      end
    end
    assert_equal all_ids.sort, found_ids
  end

  def test_in_batches_loaded_should_unscope_cursor_after_pluck
    all_ids = Post.limit(2).pluck(:id)
    # only a single clause on id (i.e. not 'id IN (?,?) AND id = ?', but only 'id = ?')
    assert_queries_match(/WHERE #{Regexp.escape(quote_table_name("posts.id"))} = \S+$/) do
      Post.where(id: all_ids).in_batches(of: 1, load: true) do |relation|
        relation.delete_all
      end
    end
  end

  def test_in_batches_should_quote_batch_order
    assert_queries_match(/ORDER BY #{Regexp.escape(quote_table_name("posts.id"))}/) do
      Post.in_batches(of: 1) do |relation|
        assert_kind_of ActiveRecord::Relation, relation
        assert_kind_of Post, relation.first
      end
    end
  end

  def test_in_batches_should_quote_batch_order_with_desc_order
    assert_queries_match(/ORDER BY #{Regexp.escape(quote_table_name("posts.id"))} DESC/) do
      Post.in_batches(of: 1, order: :desc) do |relation|
        assert_kind_of ActiveRecord::Relation, relation
        assert_kind_of Post, relation.first
      end
    end
  end

  def test_in_batches_enumerator_should_quote_batch_order_with_desc_order
    assert_queries_match(/ORDER BY #{Regexp.escape(quote_table_name("posts.id"))} DESC/) do
      relation = Post.in_batches(of: 1, order: :desc).first
      assert_kind_of ActiveRecord::Relation, relation
      assert_kind_of Post, relation.first
    end
  end

  def test_in_batches_enumerator_each_record_should_quote_batch_order_with_desc_order
    assert_queries_match(/ORDER BY #{Regexp.escape(quote_table_name("posts.id"))} DESC/) do
      Post.in_batches(of: 1, order: :desc).each_record do |record|
        assert_kind_of Post, record
      end
    end
  end

  def test_in_batches_should_not_use_records_after_yielding_them_in_case_original_array_is_modified
    not_a_post = +"not a post"
    def not_a_post.id
      raise StandardError.new("not_a_post had #id called on it")
    end

    assert_nothing_raised do
      Post.in_batches(of: 1) do |relation|
        assert_kind_of ActiveRecord::Relation, relation
        assert_kind_of Post, relation.first

        [not_a_post] * relation.count
      end
    end
  end

  def test_in_batches_should_not_ignore_default_scope_without_order_statements
    default_scope = SpecialPostWithDefaultScope.all
    posts = []
    SpecialPostWithDefaultScope.in_batches do |relation|
      posts.concat(relation)
    end
    assert_equal default_scope.pluck(:id).sort, posts.map(&:id).sort
  end

  def test_in_batches_should_use_any_column_as_primary_key
    nick_order_subscribers = Subscriber.order("nick asc")
    start_nick = nick_order_subscribers.second.nick

    subscribers = []
    Subscriber.in_batches(of: 1, start: start_nick) do |relation|
      subscribers.concat(relation)
    end

    assert_equal nick_order_subscribers[1..-1].map(&:id), subscribers.map(&:id)
  end

  def test_in_batches_should_use_any_column_as_primary_key_when_start_is_not_specified
    assert_queries_count(Subscriber.count + 1) do
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
    assert_queries_count(4) do
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
    person.update(author_id: 1)

    Post.in_batches(of: 2) do |batch|
      batch.where("author_id >= 1").update_all("author_id = author_id + 1")
    end
    assert_equal 2, person.reload.author_id # incremented only once
  end

  def test_in_batches_with_custom_columns_raises_when_start_missing_items
    assert_raises(ArgumentError, match: ":start must contain one value per cursor column") do
      Post.in_batches(start: 1, cursor: [:author_id, :id]) { }
    end
  end

  def test_in_batches_with_custom_columns_raises_when_finish_missing_items
    assert_raises(ArgumentError, match: ":finish must contain one value per cursor column") do
      Post.in_batches(finish: 10, cursor: [:author_id, :id]) { }
    end
  end

  def test_in_batches_with_custom_columns_raises_when_non_unique_columns
    ActiveRecord::Base.schema_cache.clear!

    # Non unique column.
    assert_raises(ArgumentError, match: /must include a primary key/) do
      Post.in_batches(cursor: :title) { }
    end

    # Primary key column.
    assert_nothing_raised do
      Post.in_batches(cursor: :id) { }
    end

    c = Post.lease_connection
    c.add_index(:posts, :title)
    ActiveRecord::Base.schema_cache.clear!

    # Non unique indexed column.
    assert_raises(ArgumentError, match: /must include a primary key/) do
      Post.in_batches(cursor: :title) { }
    end

    c.remove_index(:posts, :title)

    if current_adapter?(:PostgreSQLAdapter)
      c.add_index(:posts, :title, unique: true, where: "id > 5")
      ActiveRecord::Base.schema_cache.clear!

      # Column having a unique, but partial, index.
      assert_raises(ArgumentError, match: /must include a primary key/) do
        Post.in_batches(cursor: :title) { }
      end

      c.remove_index(:posts, :title)
    end

    c.add_index(:posts, :title, unique: true)
    ActiveRecord::Base.schema_cache.clear!
    assert_nothing_raised do
      Post.in_batches(cursor: :title) { }
    end
  ensure
    c.remove_index(:posts, :title)
  end

  def test_in_batches_iterating_using_custom_columns
    c = Post.lease_connection
    c.add_index(:posts, :title, unique: true)
    ActiveRecord::Base.schema_cache.clear!

    expected_posts = Post.order(id: :desc).to_a
    posts = []
    Post.in_batches(of: 1, cursor: :id, order: :desc).each_record do |post|
      posts << post
    end

    assert_equal expected_posts, posts
  ensure
    c.remove_index(:posts, :title)
  end

  def test_find_in_batches_should_return_a_sized_enumerator
    assert_equal 11, Post.find_in_batches(batch_size: 1).size
    assert_equal 6, Post.find_in_batches(batch_size: 2).size
    assert_equal 4, Post.find_in_batches(batch_size: 2, start: 4).size
    assert_equal 4, Post.find_in_batches(batch_size: 3).size
    assert_equal 1, Post.find_in_batches(batch_size: 10_000).size
  end

  [true, false].each do |load|
    test "in_batches should return limit records when limit is less than batch size and load is #{load}" do
      limit      = 3
      batch_size = 5
      total      = 0

      Post.limit(limit).in_batches(of: batch_size, load: load) do |batch|
        total += batch.count
      end

      assert_equal limit, total
    end

    test "in_batches should return limit records when limit is greater than batch size and load is #{load}" do
      limit      = 5
      batch_size = 3
      total      = 0

      Post.limit(limit).in_batches(of: batch_size, load: load) do |batch|
        total += batch.count
      end

      assert_equal limit, total
    end

    test "in_batches should return limit records when limit is greater than batch size with use_ranges and load is #{load}" do
      limit = 5
      batch_size = 3
      total = 0

      Post.limit(limit).in_batches(of: batch_size, load: load, use_ranges: true) do |batch|
        total += batch.count
      end

      assert_equal limit, total
    end

    test "in_batches should return limit records when limit is a multiple of the batch size and load is #{load}" do
      limit      = 6
      batch_size = 3
      total      = 0

      Post.limit(limit).in_batches(of: batch_size, load: load) do |batch|
        total += batch.count
      end

      assert_equal limit, total
    end

    test "in_batches should return no records if the limit is 0 and load is #{load}" do
      limit      = 0
      batch_size = 1
      total      = 0

      Post.limit(limit).in_batches(of: batch_size, load: load) do |batch|
        total += batch.count
      end

      assert_equal limit, total
    end

    test "in_batches should return all if the limit is greater than the number of records when load is #{load}" do
      limit      = @total + 1
      batch_size = 1
      total      = 0

      Post.limit(limit).in_batches(of: batch_size, load: load) do |batch|
        total += batch.count
      end

      assert_equal @total, total
    end
  end

  test ".find_each respects table alias" do
    assert_queries_count(1) do
      table_alias = Post.arel_table.alias("omg_posts")

      posts = ActiveRecord::Relation.create(Post, table: table_alias)
      posts.find_each { }
    end
  end

  test ".find_each bypasses the query cache for its own queries" do
    Post.cache do
      assert_queries_count(2) do
        Post.find_each { }
        Post.find_each { }
      end
    end
  end

  test ".find_each does not disable the query cache inside the given block" do
    Post.cache do
      Post.find_each(start: 1, finish: 1) do |post|
        assert_queries_count(1) do
          post.comments.count
          post.comments.count
        end
      end
    end
  end

  test ".find_in_batches bypasses the query cache for its own queries" do
    Post.cache do
      assert_queries_count(2) do
        Post.find_in_batches { }
        Post.find_in_batches { }
      end
    end
  end

  test ".find_in_batches does not disable the query cache inside the given block" do
    Post.cache do
      Post.find_in_batches(start: 1, finish: 1) do |batch|
        assert_queries_count(1) do
          batch.first.comments.count
          batch.first.comments.count
        end
      end
    end
  end

  test ".in_batches bypasses the query cache for its own queries" do
    Post.cache do
      assert_queries_count(4) do
        Post.in_batches { }
        Post.in_batches { }
      end
    end
  end

  test ".in_batches does not disable the query cache inside the given block" do
    Post.cache do
      Post.in_batches(start: 1, finish: 1) do |relation|
        assert_queries_count(1) do
          relation.count
          relation.count
        end
      end
    end
  end

  test ".find_each iterates over composite primary key" do
    orders = Cpk::Order.order(*Cpk::Order.primary_key).to_a

    index = 0
    Cpk::Order.find_each(batch_size: 1) do |order|
      assert_equal orders[index], order
      index += 1
    end
    assert_equal orders.size, index
  end

  test ".in_batches should start from the start option when using composite primary key" do
    order = Cpk::Order.second
    relation = Cpk::Order.in_batches(of: 1, start: order.id).first
    assert_equal order, relation.first
  end

  test ".in_batches should end at the finish option when using composite primary key" do
    order = Cpk::Order.second_to_last
    relation = Cpk::Order.in_batches(of: 1, finish: order.id).reverse_each.first
    assert_equal order, relation.last
  end

  test ".in_batches with scope and using composite primary key" do
    order1, order2 = Cpk::Order.first(2)
    shop_id, id = order1.id
    relation = Cpk::Order.where("shop_id > ? OR shop_id = ? AND id > ?", shop_id, shop_id, id).in_batches(of: 1).first
    assert_equal order2, relation.first
  end

  test ".find_each with multiple column ordering and using composite primary key" do
    Cpk::Book.insert_all!([
      { author_id: 1, id: 1 },
      { author_id: 2, id: 1 },
      { author_id: 2, id: 2 }
    ])
    books = Cpk::Book.order(author_id: :asc, id: :desc).to_a

    index = 0
    Cpk::Book.find_each(batch_size: 1, order: [:asc, :desc]) do |book|
      assert_equal books[index], book
      index += 1
    end
    assert_equal books.size, index
  end

  test ".in_batches should start from the start option when using composite primary key with multiple column ordering" do
    Cpk::Book.insert_all!([
      { author_id: 1, id: 1 },
      { author_id: 1, id: 2 },
      { author_id: 1, id: 3 }
    ])
    second_book = Cpk::Book.order(author_id: :asc, id: :desc).second
    relation = Cpk::Book.in_batches(of: 1, start: second_book.id, order: [:asc, :desc]).first
    assert_equal second_book, relation.first
  end

  test ".in_batches should end at the finish option when using composite primary key with multiple column ordering" do
    Cpk::Book.insert_all!([
      { author_id: 1, id: 1 },
      { author_id: 1, id: 2 },
      { author_id: 1, id: 3 }
    ])
    second_book = Cpk::Book.order(author_id: :asc, id: :desc).second
    relation = Cpk::Book.in_batches(of: 1, finish: second_book.id, order: [:asc, :desc]).to_a.last
    assert_equal second_book, relation.first
  end

  test ".in_batches with scope and multiple column ordering and using composite primary key" do
    Cpk::Book.insert_all!([
      { author_id: 1, id: 1 },
      { author_id: 1, id: 2 },
      { author_id: 1, id: 3 }
    ])
    book1, book2 = Cpk::Book.order(author_id: :asc, id: :desc).first(2)
    author_id, id = book1.id
    relation = Cpk::Book.where("author_id >= ? AND id < ?", author_id, id).in_batches(of: 1, order: [:asc, :desc]).first
    assert_equal book2, relation.first
  end
end
