# frozen_string_literal: true

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
    attr_reader :logger, :events

    def initialize
      super
      @logger = ::Logger.new File::NULL
      @exception = false
      @events = []
    end

    def exception?
      @exception
    end

    def sql(event)
      @events << event
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

  def test_writes_should_always_clear_cache
    assert_cache :off

    mw = middleware { |env|
      Post.first
      query_cache = ActiveRecord::Base.connection.query_cache
      assert_equal 1, query_cache.length, query_cache.keys
      Post.connection.uncached do
        # should clear the cache
        Post.create!(title: "a new post", body: "and a body")
      end
      query_cache = ActiveRecord::Base.connection.query_cache
      assert_equal 0, query_cache.length, query_cache.keys
    }
    mw.call({})

    assert_cache :off
  end

  def test_exceptional_middleware_clears_and_disables_cache_on_error
    assert_cache :off

    mw = middleware { |env|
      Task.find 1
      Task.find 1
      query_cache = ActiveRecord::Base.connection.query_cache
      assert_equal 1, query_cache.length, query_cache.keys
      raise "lol borked"
    }
    assert_raises(RuntimeError) { mw.call({}) }

    assert_cache :off
  end

  def test_query_cache_is_applied_to_legacy_connections_in_all_handlers
    old_value = ActiveRecord::Base.legacy_connection_handling
    ActiveRecord::Base.legacy_connection_handling = true

    assert_deprecated do
      ActiveRecord::Base.connection_handlers = {
        writing: ActiveRecord::Base.default_connection_handler,
        reading: ActiveRecord::ConnectionAdapters::ConnectionHandler.new
      }
    end

    ActiveRecord::Base.connected_to(role: :reading) do
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      ActiveRecord::Base.establish_connection(db_config)
    end

    mw = middleware { |env|
      reading_handler = ActiveRecord::Base.connection_handlers[:reading]
      ro_pool = reading_handler.connection_pool_list
      ro_conn = ro_pool.first.connection
      assert_predicate ActiveRecord::Base.connection, :query_cache_enabled
      assert_predicate ro_conn, :query_cache_enabled
    }

    mw.call({})
  ensure
    clean_up_legacy_connection_handlers
    ActiveRecord::Base.legacy_connection_handling = old_value
  end

  def test_query_cache_is_applied_to_all_connections
    ActiveRecord::Base.connected_to(role: :reading) do
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      ActiveRecord::Base.establish_connection(db_config)
    end

    mw = middleware { |env|
      rw_conn = ActiveRecord::Base.connection_handler.connection_pool_list(:writing).first.connection
      assert_predicate rw_conn, :query_cache_enabled

      ro_conn = ActiveRecord::Base.connection_handler.connection_pool_list(:reading).first.connection
      assert_predicate ActiveRecord::Base.connection, :query_cache_enabled
      assert_predicate ro_conn, :query_cache_enabled
    }

    mw.call({})
  ensure
    clean_up_connection_handler
  end

  if Process.respond_to?(:fork) && !in_memory_db?
    def test_query_cache_with_multiple_handlers_and_forked_processes_legacy_handling
      old_value = ActiveRecord::Base.legacy_connection_handling
      ActiveRecord::Base.legacy_connection_handling = true

      assert_deprecated do
        ActiveRecord::Base.connection_handlers = {
          writing: ActiveRecord::Base.default_connection_handler,
          reading: ActiveRecord::ConnectionAdapters::ConnectionHandler.new
        }
      end

      ActiveRecord::Base.connected_to(role: :reading) do
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        ActiveRecord::Base.establish_connection(db_config)
      end

      rd, wr = IO.pipe
      rd.binmode
      wr.binmode

      pid = fork {
        rd.close
        status = 0

        middleware { |env|
          begin
            assert_cache :clean

            # first request dirties cache
            ActiveRecord::Base.connected_to(role: :reading) do
              Post.first
              assert_cache :dirty
            end

            # should clear the cache
            Post.create!(title: "a new post", body: "and a body")

            # fails because cache is still dirty
            ActiveRecord::Base.connected_to(role: :reading) do
              assert_cache :clean
              Post.first
            end

          rescue Minitest::Assertion => e
            wr.write Marshal.dump e
            status = 1
          end
        }.call({})

        wr.close
        exit!(status)
      }

      wr.close

      Process.waitpid pid
      if !$?.success?
        raise Marshal.load(rd.read)
      else
        assert_predicate $?, :success?
      end

      rd.close
    ensure
      clean_up_legacy_connection_handlers
      ActiveRecord::Base.legacy_connection_handling = old_value
    end

    def test_query_cache_with_forked_processes
      ActiveRecord::Base.connected_to(role: :reading) do
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        ActiveRecord::Base.establish_connection(db_config)
      end

      rd, wr = IO.pipe
      rd.binmode
      wr.binmode

      pid = fork {
        rd.close
        status = 0

        middleware { |env|
          begin
            assert_cache :clean

            # first request dirties cache
            ActiveRecord::Base.connected_to(role: :reading) do
              Post.first
              assert_cache :dirty
            end

            # should clear the cache
            Post.create!(title: "a new post", body: "and a body")

            # fails because cache is still dirty
            ActiveRecord::Base.connected_to(role: :reading) do
              assert_cache :clean
              Post.first
            end

          rescue Minitest::Assertion => e
            wr.write Marshal.dump e
            status = 1
          end
        }.call({})

        wr.close
        exit!(status)
      }

      wr.close

      Process.waitpid pid
      if !$?.success?
        raise Marshal.load(rd.read)
      else
        assert_predicate $?, :success?
      end

      rd.close
    ensure
      clean_up_connection_handler
    end
  end

  def test_query_cache_across_threads
    with_temporary_connection_pool do
      if in_memory_db?
        # Separate connections to an in-memory database create an entirely new database,
        # with an empty schema etc, so we just stub out this schema on the fly.
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          connection.create_table :tasks do |t|
            t.datetime :starting
            t.datetime :ending
          end
        end
        ActiveRecord::FixtureSet.create_fixtures(self.class.fixture_path, ["tasks"], {}, ActiveRecord::Base)
      end

      ActiveRecord::Base.connection_pool.connections.each do |conn|
        assert_cache :off, conn
      end

      assert_not_predicate ActiveRecord::Base.connection, :nil?
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
      ActiveRecord::Base.connection_pool.disconnect!
    end
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
      query_cache = ActiveRecord::Base.connection.query_cache
      assert_equal 1, query_cache.length, query_cache.keys
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
      assert_no_queries { Task.find(1); Task.find(1); Task.find(2) }
    end
  end

  def test_count_queries_with_cache
    Task.cache do
      assert_queries(1) { Task.count; Task.count }
    end
  end

  def test_exists_queries_with_cache
    Post.cache do
      assert_queries(1) { Post.exists?; Post.exists? }
    end
  end

  def test_select_all_with_cache
    Post.cache do
      assert_queries(1) do
        2.times { Post.connection.select_all(Post.all) }
      end
    end
  end

  def test_select_one_with_cache
    Post.cache do
      assert_queries(1) do
        2.times { Post.connection.select_one(Post.all) }
      end
    end
  end

  def test_select_value_with_cache
    Post.cache do
      assert_queries(1) do
        2.times { Post.connection.select_value(Post.all) }
      end
    end
  end

  def test_select_values_with_cache
    Post.cache do
      assert_queries(1) do
        2.times { Post.connection.select_values(Post.all) }
      end
    end
  end

  def test_select_rows_with_cache
    Post.cache do
      assert_queries(1) do
        2.times { Post.connection.select_rows(Post.all) }
      end
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

  def test_cache_notifications_can_be_overridden
    logger = ShouldNotHaveExceptionsLogger.new
    subscriber = ActiveSupport::Notifications.subscribe "sql.active_record", logger

    connection = ActiveRecord::Base.connection.dup

    def connection.cache_notification_info(sql, name, binds)
      super.merge(neat: true)
    end

    connection.cache do
      connection.select_all "select 1"
      connection.select_all "select 1"
    end

    assert_equal true, logger.events.last.payload[:neat]
  ensure
    ActiveSupport::Notifications.unsubscribe subscriber
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

  def test_query_cache_does_not_allow_sql_key_mutation
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
      payload[:sql].downcase!
    end

    assert_raises FrozenError do
      ActiveRecord::Base.cache do
        assert_queries(1) { Task.find(1); Task.find(1) }
      end
    end
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

  def test_cache_does_not_wrap_results_in_arrays
    Task.cache do
      assert_equal 2, Task.connection.select_value("SELECT count(*) AS count_all FROM tasks")
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

  def test_cache_is_available_when_using_a_not_connected_connection
    skip "In-Memory DB can't test for using a not connected connection" if in_memory_db?
    db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary").dup
    db_config.owner_name = "test2"
    ActiveRecord::Base.connection_handler.establish_connection(db_config)
    assert_not_predicate Task, :connected?

    Task.cache do
      assert_queries(1) { Task.find(1); Task.find(1) }
    ensure
      ActiveRecord::Base.connection_handler.remove_connection_pool(db_config.owner_name)
    end
  end

  def test_query_cache_executes_new_queries_within_block
    ActiveRecord::Base.connection.enable_query_cache!

    # Warm up the cache by running the query
    assert_queries(1) do
      assert_equal 0, Post.where(title: "test").to_a.count
    end

    # Check that if the same query is run again, no queries are executed
    assert_no_queries do
      assert_equal 0, Post.where(title: "test").to_a.count
    end

    ActiveRecord::Base.connection.uncached do
      # Check that new query is executed, avoiding the cache
      assert_queries(1) do
        assert_equal 0, Post.where(title: "test").to_a.count
      end
    end
  end

  def test_query_cache_doesnt_leak_cached_results_of_rolled_back_queries
    ActiveRecord::Base.connection.enable_query_cache!
    post = Post.first

    Post.transaction do
      post.update(title: "rollback")
      assert_equal 1, Post.where(title: "rollback").to_a.count
      raise ActiveRecord::Rollback
    end

    assert_equal 0, Post.where(title: "rollback").to_a.count

    ActiveRecord::Base.connection.uncached do
      assert_equal 0, Post.where(title: "rollback").to_a.count
    end

    begin
      Post.transaction do
        post.update(title: "rollback")
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

      # Preload the type cache again (so we don't have those queries issued during our assertions)
      Task.connection.send(:reload_type_map)

      # Clear places where type information is cached
      Task.reset_column_information
      Task.initialize_find_by_cache
      Task.define_attribute_methods

      assert_no_queries do
        Task.find(1)
      end
    end
  end

  def test_query_cache_does_not_establish_connection_if_unconnected
    ActiveRecord::Base.clear_active_connections!
    assert_not ActiveRecord::Base.connection_handler.active_connections? # sanity check

    middleware {
      assert_not ActiveRecord::Base.connection_handler.active_connections?, "QueryCache forced ActiveRecord::Base to establish a connection in setup"
    }.call({})

    assert_not ActiveRecord::Base.connection_handler.active_connections?, "QueryCache forced ActiveRecord::Base to establish a connection in cleanup"
  end

  def test_query_cache_is_enabled_on_connections_established_after_middleware_runs
    ActiveRecord::Base.clear_active_connections!
    assert_not ActiveRecord::Base.connection_handler.active_connections? # sanity check

    middleware {
      assert_predicate ActiveRecord::Base.connection, :query_cache_enabled
    }.call({})
    assert_not_predicate ActiveRecord::Base.connection, :query_cache_enabled
  end

  def test_query_caching_is_local_to_the_current_thread
    ActiveRecord::Base.clear_active_connections!

    middleware {
      assert ActiveRecord::Base.connection_pool.query_cache_enabled
      assert ActiveRecord::Base.connection.query_cache_enabled

      Thread.new {
        assert_not ActiveRecord::Base.connection_pool.query_cache_enabled
        assert_not ActiveRecord::Base.connection.query_cache_enabled
      }.join
    }.call({})
  end

  def test_query_cache_is_enabled_on_all_connection_pools
    middleware {
      ActiveRecord::Base.connection_handler.connection_pool_list.each do |pool|
        assert pool.query_cache_enabled
        assert pool.connection.query_cache_enabled
      end
    }.call({})
  end

  def test_clear_query_cache_is_called_on_all_legacy_connections
    skip "with in memory db, reading role won't be able to see database on writing role" if in_memory_db?
    old_value = ActiveRecord::Base.legacy_connection_handling
    ActiveRecord::Base.legacy_connection_handling = true

    assert_deprecated do
      ActiveRecord::Base.connection_handlers = {
        writing: ActiveRecord::Base.default_connection_handler,
        reading: ActiveRecord::ConnectionAdapters::ConnectionHandler.new
      }
    end

    ActiveRecord::Base.connected_to(role: :reading) do
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      ActiveRecord::Base.establish_connection(db_config)
    end

    mw = middleware { |env|
      ActiveRecord::Base.connected_to(role: :reading) do
        @topic = Topic.first
      end

      assert @topic

      ActiveRecord::Base.connected_to(role: :writing) do
        @topic.title = "It doesn't have to be crazy at work"
        @topic.save!
      end

      assert_equal "It doesn't have to be crazy at work", @topic.title

      ActiveRecord::Base.connected_to(role: :reading) do
        @topic = Topic.first
        assert_equal "It doesn't have to be crazy at work", @topic.title
      end
    }

    mw.call({})
  ensure
    unless in_memory_db?
      clean_up_legacy_connection_handlers
      ActiveRecord::Base.legacy_connection_handling = old_value
    end
  end

  def test_clear_query_cache_is_called_on_all_connections
    skip "with in memory db, reading role won't be able to see database on writing role" if in_memory_db?

    ActiveRecord::Base.connected_to(role: :reading) do
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      ActiveRecord::Base.establish_connection(db_config)
    end

    mw = middleware { |env|
      ActiveRecord::Base.connected_to(role: :reading) do
        @topic = Topic.first
      end

      assert @topic

      ActiveRecord::Base.connected_to(role: :writing) do
        @topic.title = "It doesn't have to be crazy at work"
        @topic.save!
      end

      assert_equal "It doesn't have to be crazy at work", @topic.title

      ActiveRecord::Base.connected_to(role: :reading) do
        @topic = Topic.first
        assert_equal "It doesn't have to be crazy at work", @topic.title
      end
    }

    mw.call({})
  ensure
    clean_up_connection_handler
  end

  test "query cache is enabled in threads with shared connection" do
    ActiveRecord::Base.connection_pool.lock_thread = true

    assert_cache :off

    thread_a = Thread.new do
      middleware { |env|
        assert_cache :clean
        [200, {}, nil]
      }.call({})
    end

    thread_a.join

    ActiveRecord::Base.connection_pool.lock_thread = false
  end

  private
    def with_temporary_connection_pool
      pool_config = ActiveRecord::Base.connection_handler.send(:owner_to_pool_manager).fetch("ActiveRecord::Base").get_pool_config(ActiveRecord::Base.writing_role, :default)
      new_pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new(pool_config)

      pool_config.stub(:pool, new_pool) do
        yield
      end
    end

    def middleware(&app)
      executor = Class.new(ActiveSupport::Executor)
      ActiveRecord::QueryCache.install_executor_hooks executor
      lambda { |env| executor.wrap { app.call(env) } }
    end

    def assert_cache(state, connection = ActiveRecord::Base.connection)
      case state
      when :off
        assert_not connection.query_cache_enabled, "cache should be off"
        assert connection.query_cache.empty?, "cache should be empty"
      when :clean
        assert connection.query_cache_enabled, "cache should be on"
        assert connection.query_cache.empty?, "cache should be empty"
      when :dirty
        assert connection.query_cache_enabled, "cache should be on"
        assert_not connection.query_cache.empty?, "cache should be dirty"
      else
        raise "unknown state"
      end
    end
end

class QueryCacheExpiryTest < ActiveRecord::TestCase
  fixtures :tasks, :posts, :categories, :categories_posts

  def teardown
    Task.connection.clear_query_cache
  end

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
      assert_not Task.connection.query_cache_enabled
      Task.cache do
        assert Task.connection.query_cache_enabled
        Task.find(1)

        Task.uncached do
          assert_not Task.connection.query_cache_enabled
          Task.find(1)
        end

        assert Task.connection.query_cache_enabled
      end
      assert_not Task.connection.query_cache_enabled
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

  def test_insert_all
    skip unless supports_insert_on_duplicate_skip?

    assert_called(ActiveRecord::Base.connection, :clear_query_cache, times: 2) do
      Task.cache { Task.insert({ starting: Time.now }) }
    end

    assert_called(ActiveRecord::Base.connection, :clear_query_cache, times: 2) do
      Task.cache { Task.insert_all([{ starting: Time.now }]) }
    end
  end

  def test_insert_all_bang
    assert_called(ActiveRecord::Base.connection, :clear_query_cache, times: 2) do
      Task.cache { Task.insert!({ starting: Time.now }) }
    end

    assert_called(ActiveRecord::Base.connection, :clear_query_cache, times: 2) do
      Task.cache { Task.insert_all!([{ starting: Time.now }]) }
    end
  end

  def test_upsert_all
    skip unless supports_insert_on_duplicate_update?

    assert_called(ActiveRecord::Base.connection, :clear_query_cache, times: 2) do
      Task.cache { Task.upsert({ starting: Time.now }) }
    end

    assert_called(ActiveRecord::Base.connection, :clear_query_cache, times: 2) do
      Task.cache { Task.upsert_all([{ starting: Time.now }]) }
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
        assert_predicate p.categories, :any?
        p.categories.delete_all
      end
    end
  end

  test "threads use the same connection" do
    @connection_1 = ActiveRecord::Base.connection.object_id

    thread_a = Thread.new do
      @connection_2 = ActiveRecord::Base.connection.object_id
    end

    thread_a.join

    assert_equal @connection_1, @connection_2
  end
end
