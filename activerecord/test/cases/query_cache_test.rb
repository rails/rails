require "cases/helper"
require 'models/topic'
require 'models/task'
require 'models/category'
require 'models/post'
require 'rack'

class QueryCacheTest < ActiveRecord::TestCase
  fixtures :tasks, :topics, :categories, :posts, :categories_posts

  teardown do
    Task.connection.clear_query_cache
    ActiveRecord::Base.connection.disable_query_cache!
  end

  def test_exceptional_middleware_clears_and_disables_cache_on_error
    assert !ActiveRecord::Base.connection.query_cache_enabled, 'cache off'

    mw = middleware { |env|
      Task.find 1
      Task.find 1
      assert_equal 1, ActiveRecord::Base.connection.query_cache.length
      raise "lol borked"
    }
    assert_raises(RuntimeError) { mw.call({}) }

    assert_equal 0, ActiveRecord::Base.connection.query_cache.length
    assert !ActiveRecord::Base.connection.query_cache_enabled, 'cache off'
  end

  def test_exceptional_middleware_leaves_enabled_cache_alone
    ActiveRecord::Base.connection.enable_query_cache!

    mw = middleware { |env|
      raise "lol borked"
    }
    assert_raises(RuntimeError) { mw.call({}) }

    assert ActiveRecord::Base.connection.query_cache_enabled, 'cache on'
  end

  def test_exceptional_middleware_assigns_original_connection_id_on_error
    connection_id = ActiveRecord::Base.connection_id

    mw = middleware { |env|
      ActiveRecord::Base.connection_id = self.object_id
      raise "lol borked"
    }
    assert_raises(RuntimeError) { mw.call({}) }

    assert_equal connection_id, ActiveRecord::Base.connection_id
  end

  def test_middleware_delegates
    called = false
    mw = middleware { |env|
      called = true
      [200, {}, nil]
    }
    mw.call({})
    assert called, 'middleware should delegate'
  end

  def test_middleware_caches
    mw = middleware { |env|
      Task.find 1
      Task.find 1
      assert_equal 1, ActiveRecord::Base.connection.query_cache.length
      [200, {}, nil]
    }
    mw.call({})
  end

  def test_cache_enabled_during_call
    assert !ActiveRecord::Base.connection.query_cache_enabled, 'cache off'

    mw = middleware { |env|
      assert ActiveRecord::Base.connection.query_cache_enabled, 'cache on'
      [200, {}, nil]
    }
    mw.call({})
  end

  def test_cache_passing_a_relation
    post = Post.first
    Post.cache do
      query = post.categories.select(:post_id)
      assert Post.connection.select_all(query).is_a?(ActiveRecord::Result)
    end
  end

  def test_find_queries
    assert_queries(2) { Task.find(1); Task.find(1) }
  end

  def test_find_queries_with_cache
    Task.cache do
      assert_queries(1) { Task.find(1); Task.find(1) }
    end
  end

  def test_find_queries_with_cache_multi_record
    Task.cache do
      assert_queries(2) { Task.find(1); Task.find(1); Task.find(2) }
    end
  end

  def test_find_queries_with_multi_cache_blocks
    Task.cache do
      Task.cache do
        assert_queries(2) { Task.find(1); Task.find(2) }
      end
      assert_queries(0) { Task.find(1); Task.find(1); Task.find(2) }
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
      assert_queries(1) { Topic.find(1); Topic.find(1); }
    end

    ActiveRecord::Base.cache do
      assert_queries(1) { Task.find(1); Task.find(1) }
    end
  end

  def test_cache_does_not_wrap_string_results_in_arrays
    Task.cache do
      # Oracle adapter returns count() as Integer or Float
      if current_adapter?(:OracleAdapter)
        assert_kind_of Numeric, Task.connection.select_value("SELECT count(*) AS count_all FROM tasks")
      elsif current_adapter?(:SQLite3Adapter, :Mysql2Adapter, :PostgreSQLAdapter)
        # Future versions of the sqlite3 adapter will return numeric
        assert_instance_of Fixnum, Task.connection.select_value("SELECT count(*) AS count_all FROM tasks")
      else
        assert_instance_of String, Task.connection.select_value("SELECT count(*) AS count_all FROM tasks")
      end
    end
  end

  def test_cache_is_ignored_for_locked_relations
    task = Task.find 1

    Task.cache do
      assert_queries(2) { task.lock!; task.lock! }
    end
  end

  def test_cache_is_available_when_connection_is_connected
    conf = ActiveRecord::Base.configurations

    ActiveRecord::Base.configurations = {}
    Task.cache do
      assert_queries(1) { Task.find(1); Task.find(1) }
    end
  ensure
    ActiveRecord::Base.configurations = conf
  end

  def test_cache_is_not_available_when_using_a_not_connected_connection
    spec_name = Task.connection_specification_name
    conf = ActiveRecord::Base.configurations['arunit'].merge('name' => 'test2')
    ActiveRecord::Base.connection_handler.establish_connection(conf)
    Task.connection_specification_name = "test2"
    refute Task.connected?

    Task.cache do
      Task.connection # warmup postgresql connection setup queries
      assert_queries(2) { Task.find(1); Task.find(1) }
    end
  ensure
    ActiveRecord::Base.connection_handler.remove_connection(Task.connection_specification_name)
    Task.connection_specification_name = spec_name
  end

  def test_query_cache_doesnt_leak_cached_results_of_rolled_back_queries
    ActiveRecord::Base.connection.enable_query_cache!
    post = Post.first

    Post.transaction do
      post.update_attributes(title: 'rollback')
      assert_equal 1, Post.where(title: 'rollback').to_a.count
      raise ActiveRecord::Rollback
    end

    assert_equal 0, Post.where(title: 'rollback').to_a.count

    ActiveRecord::Base.connection.uncached do
      assert_equal 0, Post.where(title: 'rollback').to_a.count
    end

    begin
      Post.transaction do
        post.update_attributes(title: 'rollback')
        assert_equal 1, Post.where(title: 'rollback').to_a.count
        raise 'broken'
      end
    rescue Exception
    end

    assert_equal 0, Post.where(title: 'rollback').to_a.count

    ActiveRecord::Base.connection.uncached do
      assert_equal 0, Post.where(title: 'rollback').to_a.count
    end
  end

  private
    def middleware(&app)
      executor = Class.new(ActiveSupport::Executor)
      ActiveRecord::QueryCache.install_executor_hooks executor
      lambda { |env| executor.wrap { app.call(env) } }
    end
end

class QueryCacheExpiryTest < ActiveRecord::TestCase
  fixtures :tasks, :posts, :categories, :categories_posts

  def test_cache_gets_cleared_after_migration
    # warm the cache
    Post.find(1)

    # change the column definition
    Post.connection.change_column :posts, :title, :string, limit: 80
    assert_nothing_raised { Post.find(1) }

    # restore the old definition
    Post.connection.change_column :posts, :title, :string
  end

  def test_find
    assert_called(Task.connection, :clear_query_cache) do
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
  end

  def test_update
    assert_called(Task.connection, :clear_query_cache, times: 2) do
      Task.cache do
        task = Task.find(1)
        task.starting = Time.now.utc
        task.save!
      end
    end
  end

  def test_destroy
    assert_called(Task.connection, :clear_query_cache, times: 2) do
      Task.cache do
        Task.find(1).destroy
      end
    end
  end

  def test_insert
    assert_called(ActiveRecord::Base.connection, :clear_query_cache, times: 2) do
      Task.cache do
        Task.create!
      end
    end
  end

  def test_cache_is_expired_by_habtm_update
    assert_called(ActiveRecord::Base.connection, :clear_query_cache, times: 2) do
      ActiveRecord::Base.cache do
        c = Category.first
        p = Post.first
        p.categories << c
      end
    end
  end

  def test_cache_is_expired_by_habtm_delete
    assert_called(ActiveRecord::Base.connection, :clear_query_cache, times: 2) do
      ActiveRecord::Base.cache do
        p = Post.find(1)
        assert p.categories.any?
        p.categories.delete_all
      end
    end
  end
end
