require "cases/helper"
require "models/topic"
require "models/task"
require "models/category"
require "models/post"
require "rack"

class QueryCacheTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  fixtures :tasks, :topics, :categories, :posts, :categories_posts

  class ShouldNotHaveExceptionsLogger < ActiveRecord::LogSubscriber
    attr_reader :logger

    def initialize
      super
      @logger = ::Logger.new File::NULL
      @exception = false
    end

    def exception?
      @exception
    end

    def sql(event)
      super
    rescue
      @exception = true
    end
  end

  def teardown
    Task.connection.clear_query_cache
    ActiveRecord::Base.connection.disable_query_cache!
    super
  end

  def test_exceptional_middleware_clears_and_disables_cache_on_error
    assert_cache :off

    mw = middleware { |env|
      Task.find 1
      Task.find 1
      assert_equal 1, ActiveRecord::Base.connection.query_cache.length
      raise "lol borked"
    }
    assert_raises(RuntimeError) { mw.call({}) }

    assert_cache :off
  end

  def test_query_cache_across_threads
    ActiveRecord::Base.connection_pool.connections.each do |conn|
      assert_cache :off, conn
    end

    assert !ActiveRecord::Base.connection.nil?
    assert_cache :off

    middleware {
      assert_cache :clean

      Task.find 1
      assert_cache :dirty

      thread_1_connection = ActiveRecord::Base.connection
      ActiveRecord::Base.clear_active_connections!
      assert_cache :off, thread_1_connection

      started = Concurrent::Event.new
      checked = Concurrent::Event.new

      thread_2_connection = nil
      thread = Thread.new {
        thread_2_connection = ActiveRecord::Base.connection

        assert_equal thread_2_connection, thread_1_connection
        assert_cache :off

        middleware {
          assert_cache :clean

          Task.find 1
          assert_cache :dirty

          started.set
          checked.wait

          ActiveRecord::Base.clear_active_connections!
        }.call({})
      }

      started.wait

      thread_1_connection = ActiveRecord::Base.connection
      assert_not_equal thread_1_connection, thread_2_connection
      assert_cache :dirty, thread_2_connection
      checked.set
      thread.join

      assert_cache :off, thread_2_connection
    }.call({})

    ActiveRecord::Base.connection_pool.connections.each do |conn|
      assert_cache :off, conn
    end
  ensure
    ActiveRecord::Base.clear_all_connections!
  end

  def test_middleware_delegates
    called = false
    mw = middleware { |env|
      called = true
      [200, {}, nil]
    }
    mw.call({})
    assert called, "middleware should delegate"
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
    assert_cache :off

    mw = middleware { |env|
      assert_cache :clean
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

  def test_cache_does_not_raise_exceptions
    logger = ShouldNotHaveExceptionsLogger.new
    subscriber = ActiveSupport::Notifications.subscribe "sql.active_record", logger

    ActiveRecord::Base.cache do
      assert_queries(1) { Task.find(1); Task.find(1) }
    end

    assert_not_predicate logger, :exception?
  ensure
    ActiveSupport::Notifications.unsubscribe subscriber
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
        assert_instance_of 0.class, Task.connection.select_value("SELECT count(*) AS count_all FROM tasks")
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
    conf = ActiveRecord::Base.configurations["arunit"].merge("name" => "test2")
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
      post.update_attributes(title: "rollback")
      assert_equal 1, Post.where(title: "rollback").to_a.count
      raise ActiveRecord::Rollback
    end

    assert_equal 0, Post.where(title: "rollback").to_a.count

    ActiveRecord::Base.connection.uncached do
      assert_equal 0, Post.where(title: "rollback").to_a.count
    end

    begin
      Post.transaction do
        post.update_attributes(title: "rollback")
        assert_equal 1, Post.where(title: "rollback").to_a.count
        raise "broken"
      end
    rescue Exception
    end

    assert_equal 0, Post.where(title: "rollback").to_a.count

    ActiveRecord::Base.connection.uncached do
      assert_equal 0, Post.where(title: "rollback").to_a.count
    end
  end

  def test_query_cached_even_when_types_are_reset
    Task.cache do
      # Warm the cache
      Task.find(1)

      Task.connection.type_map.clear

      # Preload the type cache again (so we don't have those queries issued during our assertions)
      Task.connection.send(:initialize_type_map, Task.connection.type_map)

      # Clear places where type information is cached
      Task.reset_column_information
      Task.initialize_find_by_cache

      assert_queries(0) do
        Task.find(1)
      end
    end
  end

  def test_query_cache_does_not_establish_connection_if_unconnected
    ActiveRecord::Base.clear_active_connections!
    refute ActiveRecord::Base.connection_handler.active_connections? # sanity check

    middleware {
      refute ActiveRecord::Base.connection_handler.active_connections?, "QueryCache forced ActiveRecord::Base to establish a connection in setup"
    }.call({})

    refute ActiveRecord::Base.connection_handler.active_connections?, "QueryCache forced ActiveRecord::Base to establish a connection in cleanup"
  end

  def test_query_cache_is_enabled_on_connections_established_after_middleware_runs
    ActiveRecord::Base.clear_active_connections!
    refute ActiveRecord::Base.connection_handler.active_connections? # sanity check

    middleware {
      assert ActiveRecord::Base.connection.query_cache_enabled, "QueryCache did not get lazily enabled"
    }.call({})
  end

  def test_query_caching_is_local_to_the_current_thread
    ActiveRecord::Base.clear_active_connections!

    middleware {
      assert ActiveRecord::Base.connection_pool.query_cache_enabled
      assert ActiveRecord::Base.connection.query_cache_enabled

      Thread.new {
        refute ActiveRecord::Base.connection_pool.query_cache_enabled
        refute ActiveRecord::Base.connection.query_cache_enabled
      }.join
    }.call({})
  end

  private
    def middleware(&app)
      executor = Class.new(ActiveSupport::Executor)
      ActiveRecord::QueryCache.install_executor_hooks executor
      lambda { |env| executor.wrap { app.call(env) } }
    end

    def assert_cache(state, connection = ActiveRecord::Base.connection)
      case state
      when :off
        assert !connection.query_cache_enabled, "cache should be off"
        assert connection.query_cache.empty?, "cache should be empty"
      when :clean
        assert connection.query_cache_enabled, "cache should be on"
        assert connection.query_cache.empty?, "cache should be empty"
      when :dirty
        assert connection.query_cache_enabled, "cache should be on"
        assert !connection.query_cache.empty?, "cache should be dirty"
      else
        raise "unknown state"
      end
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
