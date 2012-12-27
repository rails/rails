require 'cases/helper'
require 'models/post'
require 'models/subscriber'

class FindInGroupsTest < ActiveRecord::TestCase
  fixtures :posts

  def setup
    @posts = Post.order("id asc")
    @total = Post.count
    @by_column = :type
    Post.count('id') # preheat arel's table cache
  end

  def test_warn_if_limit_scope_is_set
    ActiveRecord::Base.logger.expects(:warn)
    Post.limit(1).find_in_groups(@by_column) { |post| post }
  end

  def test_warn_if_order_scope_is_set
    ActiveRecord::Base.logger.expects(:warn)
    Post.order("title").find_in_groups(@by_column) { |post| post }
  end

  def test_warn_if_group_scope_is_set
    ActiveRecord::Base.logger.expects(:warn)
    Post.group("title").find_in_groups(@by_column) { |post| post }
  end

  def test_find_in_groups_should_return_groups
    count = Post.select(@by_column).map(&@by_column).compact.uniq.count
    assert_queries(count + 1) do
      Post.find_in_groups(@by_column) do |group|
        assert_kind_of ActiveRecord::Relation, group
        assert_kind_of Post, group.first
      end
    end
  end

  def test_find_in_groups_should_yeild_correct_distinct_values
    actual_values = Post.select(@by_column).uniq
    grouped_column_values = []
    distinct_values = Post.find_in_groups(@by_column) do |group, value|
      grouped_column_values << value
    end
    assert_equal distinct_values.map(&@by_column), grouped_column_values
    assert_equal actual_values.map(&@by_column), grouped_column_values
  end

  def test_find_in_groups_should_ignore_the_order_default_scope
    # First post is with title scope
    first_post = PostWithDefaultScope.first
    posts = []
    PostWithDefaultScope.find_in_groups(@by_column) do |group|
      posts.concat(group.to_a)
    end
    # posts.first will be ordered using id only. Title order scope should not apply here
    assert_not_equal first_post, posts.first
    assert_equal posts(:welcome), posts.first
  end
end
