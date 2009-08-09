require "cases/helper"
require 'models/topic'
require 'models/reply'
require 'models/task'
require 'models/course'
require 'models/category'
require 'models/post'


class QueryCacheTest < ActiveRecord::TestCase
  fixtures :tasks, :topics, :categories, :posts, :categories_posts

  def test_find_queries
    assert_queries(2) { Task.find(1); Task.find(1) }
  end

  def test_find_queries_with_cache
    Task.cache do
      assert_queries(1) { Task.find(1); Task.find(1) }
    end
  end

  def test_count_queries_with_cache
    Task.cache do
      assert_queries(1) { Task.count; Task.count }
    end
  end

  def test_query_cache_dups_results_correctly
    Task.cache do
      now  = Time.now.utc
      task = Task.find 1
      assert_not_equal now, task.starting
      task.starting = now
      task.reload
      assert_not_equal now, task.starting
    end
  end

  def test_cache_is_flat
    Task.cache do
      Topic.columns # don't count this query
      assert_queries(1) { Topic.find(1); Topic.find(1); }
    end

    ActiveRecord::Base.cache do
      assert_queries(1) { Task.find(1); Task.find(1) }
    end
  end

  def test_cache_does_not_wrap_string_results_in_arrays
    Task.cache do
      # Oracle adapter returns count() as Fixnum or Float
      if current_adapter?(:OracleAdapter)
        assert Task.connection.select_value("SELECT count(*) AS count_all FROM tasks").is_a?(Numeric)
      else
        assert_instance_of String, Task.connection.select_value("SELECT count(*) AS count_all FROM tasks")
      end
    end
  end
end

class QueryCacheExpiryTest < ActiveRecord::TestCase
  fixtures :tasks, :posts, :categories, :categories_posts

  def test_find
    Task.connection.expects(:clear_query_cache).times(1)

    assert !Task.connection.query_cache_enabled
    Task.cache do
      assert Task.connection.query_cache_enabled
      Task.find(1)

      Task.uncached do
        assert !Task.connection.query_cache_enabled
        Task.find(1)
      end

      assert Task.connection.query_cache_enabled
    end
    assert !Task.connection.query_cache_enabled
  end

  def test_update
    Task.connection.expects(:clear_query_cache).times(2)

    Task.cache do
      task = Task.find(1)
      task.starting = Time.now.utc
      task.save!
    end
  end

  def test_destroy
    Task.connection.expects(:clear_query_cache).times(2)

    Task.cache do
      Task.find(1).destroy
    end
  end

  def test_insert
    ActiveRecord::Base.connection.expects(:clear_query_cache).times(2)

    Task.cache do
      Task.create!
    end
  end

  def test_cache_is_expired_by_habtm_update
    ActiveRecord::Base.connection.expects(:clear_query_cache).times(2)
    ActiveRecord::Base.cache do
      c = Category.find(:first)
      p = Post.find(:first)
      p.categories << c
    end
  end

  def test_cache_is_expired_by_habtm_delete
    ActiveRecord::Base.connection.expects(:clear_query_cache).times(2)
    ActiveRecord::Base.cache do
      c = Category.find(1)
      p = Post.find(1)
      assert p.categories.any?
      p.categories.delete_all
    end
  end
end
