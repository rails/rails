# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/task"
require "models/category"
require "models/post"

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
    Task.connection_pool.clear_query_cache
    ActiveRecord::Base.connection_pool.disable_query_cache!
    super
  end

  def test_execute_clear_cache
    assert_cache :off

    mw = middleware { |env|
      Post.first
      query_cache = ActiveRecord::Base.connection_pool.query_cache
      assert_equal 1, query_cache.size, query_cache.inspect
      Post.lease_connection.execute("SELECT 1")
      query_cache = ActiveRecord::Base.connection_pool.query_cache
      assert_equal 0, query_cache.size, query_cache.inspect
    }
    mw.call({})

    assert_cache :off
  end

  def test_exec_query_clear_cache
    assert_cache :off

    mw = middleware { |env|
      Post.first
      query_cache = ActiveRecord::Base.connection_pool.query_cache
      assert_equal 1, query_cache.size, query_cache.inspect
      Post.lease_connection.exec_query("SELECT 1")
      query_cache = ActiveRecord::Base.connection_pool.query_cache
      assert_equal 0, query_cache.size, query_cache.inspect
    }
    mw.call({})

    assert_cache :off
  end

  def test_writes_should_always_clear_cache
    assert_cache :off

    mw = middleware { |env|
      Post.first
      query_cache = ActiveRecord::Base.connection_pool.query_cache
      assert_equal 1, query_cache.size, query_cache.inspect
      Post.lease_connection.uncached do
        # should clear the cache
        Post.create!(title: "a new post", body: "and a body")
      end
      query_cache = ActiveRecord::Base.connection_pool.query_cache
      assert_equal 0, query_cache.size, query_cache.inspect
    }
    mw.call({})

    assert_cache :off
  end

  def test_reads_dont_clear_disabled_cache
    assert_cache :off

    mw = middleware { |env|
      Post.first
      query_cache = ActiveRecord::Base.connection_pool.query_cache
      assert_equal 1, query_cache.size, query_cache.inspect
      Post.lease_connection.uncached do
        Post.count # shouldn't clear the cache
      end
      query_cache = ActiveRecord::Base.connection_pool.query_cache
      assert_equal 1, query_cache.size, query_cache.inspect
    }
    mw.call({})

    assert_cache :off
  end

  def test_exceptional_middleware_clears_and_disables_cache_on_error
    assert_cache :off

    mw = middleware { |env|
      Task.find 1
      Task.find 1
      query_cache = ActiveRecord::Base.connection_pool.query_cache
      assert_equal 1, query_cache.size, query_cache.inspect
      raise "lol borked"
    }
    assert_raises(RuntimeError) { mw.call({}) }

    assert_cache :off
  end

  def test_query_cache_is_applied_to_all_connections
    ActiveRecord::Base.connected_to(role: :reading) do
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      ActiveRecord::Base.establish_connection(db_config)
    end

    mw = middleware { |env|
      ActiveRecord::Base.connection_handler.connection_pool_list(:all).each do |pool|
        assert_predicate pool.lease_connection, :query_cache_enabled
      end
    }

    mw.call({})
  ensure
    clean_up_connection_handler
  end

  def test_cache_is_not_applied_when_config_is_false
    ActiveRecord::Base.connected_to(role: :reading) do
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      ActiveRecord::Base.establish_connection(db_config.configuration_hash.merge(query_cache: false))
    end

    mw = middleware do |env|
      ActiveRecord::Base.connected_to(role: :reading) do
        assert_cache :off
        assert_nil ActiveRecord::Base.lease_connection.pool.query_cache.instance_variable_get(:@max_size)
      end
    end

    mw.call({})
  ensure
    clean_up_connection_handler
  end

  def test_cache_is_applied_when_config_is_string
    ActiveRecord::Base.connected_to(role: :reading) do
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      ActiveRecord::Base.establish_connection(db_config.configuration_hash.merge(query_cache: "unlimited"))
    end

    mw = middleware do |env|
      ActiveRecord::Base.connected_to(role: :reading) do
        assert_cache :clean
        assert_nil ActiveRecord::Base.lease_connection.pool.query_cache.instance_variable_get(:@max_size)
      end
    end

    mw.call({})
  ensure
    clean_up_connection_handler
  end

  def test_cache_is_applied_when_config_is_integer
    ActiveRecord::Base.connected_to(role: :reading) do
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      ActiveRecord::Base.establish_connection(db_config.configuration_hash.merge(query_cache: 42))
    end

    mw = middleware do |env|
      ActiveRecord::Base.connected_to(role: :reading) do
        assert_cache :clean
        assert_equal 42, ActiveRecord::Base.lease_connection.pool.query_cache.instance_variable_get(:@max_size)
      end
    end

    mw.call({})
  ensure
    clean_up_connection_handler
  end

  def test_cache_is_applied_when_config_is_nil
    ActiveRecord::Base.connected_to(role: :reading) do
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      ActiveRecord::Base.establish_connection(db_config.configuration_hash.merge(query_cache: nil))
    end

    mw = middleware do |env|
      ActiveRecord::Base.connected_to(role: :reading) do
        assert_cache :clean
        assert_equal ActiveRecord::ConnectionAdapters::QueryCache::DEFAULT_SIZE, ActiveRecord::Base.lease_connection.pool.query_cache.instance_variable_get(:@max_size)
      end
    end

    mw.call({})
  ensure
    clean_up_connection_handler
  end

  if Process.respond_to?(:fork) && !in_memory_db?
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
        ActiveRecord::FixtureSet.create_fixtures(self.class.fixture_paths, ["tasks"], {}, ActiveRecord::Base)
      end

      ActiveRecord::Base.connection_pool.connections.each do |conn|
        assert_cache :off, conn
      end

      assert_not_predicate ActiveRecord::Base.lease_connection, :nil?
      assert_cache :off

      middleware {
        assert_cache :clean

        Task.find 1
        assert_cache :dirty

        thread_1_connection = ActiveRecord::Base.lease_connection
        ActiveRecord::Base.connection_handler.clear_active_connections!(:all)
        assert_cache :off, thread_1_connection

        started = Concurrent::Event.new
        checked = Concurrent::Event.new

        thread_2_connection = nil
        thread = Thread.new {
          thread_2_connection = ActiveRecord::Base.lease_connection

          assert_equal thread_2_connection, thread_1_connection
          assert_cache :off

          middleware {
            assert_cache :clean

            Task.find 1
            assert_cache :dirty

            started.set
            checked.wait

            ActiveRecord::Base.connection_handler.clear_active_connections!(:all)
          }.call({})
        }

        started.wait

        thread_1_connection = ActiveRecord::Base.lease_connection
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
      query_cache = ActiveRecord::Base.connection_pool.query_cache
      assert_equal 1, query_cache.size, query_cache.inspect
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
      assert Post.lease_connection.select_all(query).is_a?(ActiveRecord::Result)
    end
  end

  def test_find_queries
    assert_queries_count(2) { Task.find(1); Task.find(1) }
  end

  def test_find_queries_with_cache
    Task.cache do
      assert_queries_count(1) { Task.find(1); Task.find(1) }
    end
  end

  def test_find_queries_with_cache_multi_record
    Task.cache do
      assert_queries_count(2) { Task.find(1); Task.find(1); Task.find(2) }
    end
  end

  def test_find_queries_with_multi_cache_blocks
    Task.cache do
      Task.cache do
        assert_queries_count(2) { Task.find(1); Task.find(2) }
      end
      assert_no_queries { Task.find(1); Task.find(1); Task.find(2) }
    end
  end

  def test_count_queries_with_cache
    Task.cache do
      assert_queries_count(1) { Task.count; Task.count }
    end
  end

  def test_exists_queries_with_cache
    Post.cache do
      assert_queries_count(1) { Post.exists?; Post.exists? }
    end
  end

  def test_select_all_with_cache
    Post.cache do
      assert_queries_count(1) do
        2.times { Post.lease_connection.select_all(Post.all) }
      end
    end
  end

  def test_select_one_with_cache
    Post.cache do
      assert_queries_count(1) do
        2.times { Post.lease_connection.select_one(Post.all) }
      end
    end
  end

  def test_select_value_with_cache
    Post.cache do
      assert_queries_count(1) do
        2.times { Post.lease_connection.select_value(Post.all) }
      end
    end
  end

  def test_select_values_with_cache
    Post.cache do
      assert_queries_count(1) do
        2.times { Post.lease_connection.select_values(Post.all) }
      end
    end
  end

  def test_select_rows_with_cache
    Post.cache do
      assert_queries_count(1) do
        2.times { Post.lease_connection.select_rows(Post.all) }
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

    connection = ActiveRecord::Base.lease_connection.dup

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
      assert_queries_count(1) { Task.find(1); Task.find(1) }
    end

    assert_not_predicate logger, :exception?
  ensure
    ActiveSupport::Notifications.unsubscribe subscriber
  end

  def test_query_cache_does_not_allow_sql_key_mutation
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
      payload[:sql].downcase! if payload[:name] == "Task Load"
    end

    ActiveRecord::Base.cache do
      assert_queries_count(1) do
        assert_raises FrozenError do
          Task.find(1)
        end
      end
    end
  ensure
    ActiveSupport::Notifications.unsubscribe subscriber
  end

  def test_cache_is_flat
    Task.cache do
      assert_queries_count(1) { Topic.find(1); Topic.find(1) }
    end

    ActiveRecord::Base.cache do
      assert_queries_count(1) { Task.find(1); Task.find(1) }
    end
  end

  def test_cache_does_not_wrap_results_in_arrays
    Task.cache do
      assert_equal 2, Task.lease_connection.select_value("SELECT count(*) AS count_all FROM tasks")
    end
  end

  def test_cache_is_ignored_for_locked_relations
    task = Task.find 1

    Task.cache do
      assert_queries_count(2) { task.lock!; task.lock! }
    end
  end

  def test_cache_is_available_when_connection_is_connected
    conf = ActiveRecord::Base.configurations

    ActiveRecord::Base.configurations = {}
    Task.cache do
      assert_queries_count(1) { Task.find(1); Task.find(1) }
    end
  ensure
    ActiveRecord::Base.configurations = conf
  end

  def test_cache_is_available_when_using_a_not_connected_connection
    skip "In-Memory DB can't test for using a not connected connection" if in_memory_db?
    db_config = ActiveRecord::Base.connection_db_config
    original_connection = ActiveRecord::Base.remove_connection

    ActiveRecord::Base.establish_connection(db_config)
    assert_not_predicate Task, :connected?

    Task.cache do
      assert_queries_count(1) { Task.find(1) }
      assert_no_queries { Task.find(1) }
    ensure
      ActiveRecord::Base.establish_connection(original_connection)
    end
  end

  def test_query_cache_executes_new_queries_within_block
    ActiveRecord::Base.lease_connection.enable_query_cache!

    # Warm up the cache by running the query
    assert_queries_count(1) do
      assert_equal 0, Post.where(title: "test").to_a.count
    end

    # Check that if the same query is run again, no queries are executed
    assert_no_queries do
      assert_equal 0, Post.where(title: "test").to_a.count
    end

    ActiveRecord::Base.lease_connection.uncached do
      # Check that new query is executed, avoiding the cache
      assert_queries_count(1) do
        assert_equal 0, Post.where(title: "test").to_a.count
      end
    end
  end

  def test_query_cache_doesnt_leak_cached_results_of_rolled_back_queries
    ActiveRecord::Base.lease_connection.enable_query_cache!
    post = Post.first

    Post.transaction do
      post.update(title: "rollback")
      assert_equal 1, Post.where(title: "rollback").to_a.count
      raise ActiveRecord::Rollback
    end

    assert_equal 0, Post.where(title: "rollback").to_a.count

    ActiveRecord::Base.lease_connection.uncached do
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

    ActiveRecord::Base.lease_connection.uncached do
      assert_equal 0, Post.where(title: "rollback").to_a.count
    end
  end

  def test_query_cached_even_when_types_are_reset
    Task.cache do
      # Warm the cache
      Task.find(1)

      # Preload the type cache again (so we don't have those queries issued during our assertions)
      Task.lease_connection.send(:reload_type_map) if Task.lease_connection.respond_to?(:reload_type_map, true)

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
    ActiveRecord::Base.connection_handler.clear_active_connections!(:all)
    assert_not ActiveRecord::Base.connection_handler.active_connections?(:all) # Double check they are cleared

    middleware {
      assert_not ActiveRecord::Base.connection_handler.active_connections?(:all), "QueryCache forced ActiveRecord::Base to establish a connection in setup"
    }.call({})

    assert_not ActiveRecord::Base.connection_handler.active_connections?(:all), "QueryCache forced ActiveRecord::Base to establish a connection in cleanup"
  end

  def test_query_cache_is_enabled_on_connections_established_after_middleware_runs
    ActiveRecord::Base.connection_handler.clear_active_connections!(:all)
    assert_not ActiveRecord::Base.connection_handler.active_connections?(:all) # Double check they are cleared

    middleware {
      assert_predicate ActiveRecord::Base.lease_connection, :query_cache_enabled
    }.call({})
    assert_not_predicate ActiveRecord::Base.lease_connection, :query_cache_enabled
  end

  def test_query_caching_is_local_to_the_current_thread
    ActiveRecord::Base.connection_handler.clear_active_connections!(:all)

    middleware {
      assert ActiveRecord::Base.connection_pool.query_cache_enabled
      assert ActiveRecord::Base.connection_pool.query_cache_enabled

      Thread.new {
        assert_not ActiveRecord::Base.connection_pool.query_cache_enabled
        assert_not ActiveRecord::Base.connection_pool.query_cache_enabled

        ActiveRecord::Base.connection_handler.clear_active_connections!(:all)
      }.join
    }.call({})
  end

  def test_query_cache_is_enabled_on_all_connection_pools
    middleware {
      ActiveRecord::Base.connection_handler.connection_pool_list(:all).each do |pool|
        assert pool.query_cache_enabled
        assert pool.with_connection(&:query_cache_enabled)
      end
    }.call({})
  end

  # with in memory db, reading role won't be able to see database on writing role
  unless in_memory_db?
    def test_clear_query_cache_is_called_on_all_connections
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
          @topic.title = "Topic title"
          @topic.save!
        end

        assert_equal "Topic title", @topic.title

        ActiveRecord::Base.connected_to(role: :reading) do
          @topic = Topic.first
          assert_equal "Topic title", @topic.title
        end
      }

      mw.call({})
    ensure
      clean_up_connection_handler
    end
  end

  test "query cache is enabled in threads with shared connection" do
    ActiveRecord::Base.connection_pool.pin_connection!(ActiveSupport::IsolatedExecutionState.context)

    begin
      assert_cache :off
      ActiveRecord::Base.lease_connection.enable_query_cache!
      assert_cache :clean

      thread_a = Thread.new do
        middleware { |env|
          assert_cache :clean
          [200, {}, nil]
        }.call({})
      end

      thread_a.join
    ensure
      ActiveRecord::Base.connection_pool.unpin_connection!
    end
  end

  test "query cache is cleared for all thread when a connection is shared" do
    ActiveRecord::Base.connection_pool.pin_connection!(ActiveSupport::IsolatedExecutionState.context)

    begin
      assert_cache :off
      ActiveRecord::Base.lease_connection.enable_query_cache!
      assert_cache :clean

      Post.first
      assert_cache :dirty

      thread_a = Thread.new do
        middleware { |env|
          assert_cache :dirty # The cache is shared with the main thread

          Post.first
          assert_cache :dirty

          Post.delete_all

          assert_cache :clean

          [200, {}, nil]
        }.call({})
      end

      thread_a.join

      assert_cache :clean
    ensure
      ActiveRecord::Base.connection_pool.unpin_connection!
    end
  end

  def test_query_cache_uncached_dirties
    mw = middleware { |env|
      Post.first
      assert_no_changes -> { ActiveRecord::Base.connection_pool.query_cache.size } do
        Post.uncached(dirties: false) { Post.create!(title: "a new post", body: "and a body") }
      end

      assert_changes -> { ActiveRecord::Base.connection_pool.query_cache.size }, from: 1, to: 0 do
        Post.uncached(dirties: true) { Post.create!(title: "a new post", body: "and a body") }
      end
    }
    mw.call({})
  end

  def test_query_cache_connection_uncached_dirties
    mw = middleware { |env|
      Post.first
      assert_no_changes -> { ActiveRecord::Base.connection_pool.query_cache.size } do
        Post.lease_connection.uncached(dirties: false) { Post.create!(title: "a new post", body: "and a body") }
      end

      assert_changes -> { ActiveRecord::Base.connection_pool.query_cache.size }, from: 1, to: 0 do
        Post.lease_connection.uncached(dirties: true) { Post.create!(title: "a new post", body: "and a body") }
      end
    }
    mw.call({})
  end

  def test_query_cache_uncached_dirties_disabled_with_nested_cache
    mw = middleware { |env|
      Post.first
      assert_changes -> { ActiveRecord::Base.connection_pool.query_cache.size }, from: 1, to: 0 do
        Post.uncached(dirties: false) do
          Post.cache do
            Post.create!(title: "a new post", body: "and a body")
          end
        end
      end

      Post.first
      assert_changes -> { ActiveRecord::Base.connection_pool.query_cache.size }, from: 1, to: 0 do
        Post.lease_connection.uncached(dirties: false) do
          Post.lease_connection.cache do
            Post.create!(title: "a new post", body: "and a body")
          end
        end
      end
    }
    mw.call({})
  end

  private
    def with_temporary_connection_pool(&block)
      pool_config = ActiveRecord::Base.lease_connection.pool.pool_config
      new_pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new(pool_config)

      pool_config.stub(:pool, new_pool, &block)
    end

    def middleware(&app)
      executor = Class.new(ActiveSupport::Executor)
      ActiveRecord::QueryCache.install_executor_hooks executor
      lambda { |env| executor.wrap { app.call(env) } }
    end

    def assert_cache(state, connection = ActiveRecord::Base.lease_connection)
      case state
      when :off
        assert_not connection.query_cache_enabled, "cache should be off"
        if connection.query_cache.nil?
          assert_nil connection.query_cache
        else
          assert_predicate connection.query_cache, :empty?, "cache should be nil or empty"
        end
      when :clean
        assert connection.query_cache_enabled, "cache should be on"
        assert_predicate connection.query_cache, :empty?, "cache should be empty"
      when :dirty
        assert connection.query_cache_enabled, "cache should be on"
        assert_not connection.query_cache.empty?, "cache should be dirty"
      else
        raise "unknown state"
      end
    end
end

class QueryCacheMutableParamTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  class JsonObj < ActiveRecord::Base
    self.table_name = "json_objs"

    attribute :payload, :json
  end

  class ObjectFixedHash < Struct.new(:a, :b)
    # this isn't very realistic, but it is the worst case and therefore a good
    # case to test
    def hash
      1
    end
  end

  def setup
    ActiveRecord::Base.lease_connection.create_table("json_objs", force: true) do |t|
      if current_adapter?(:PostgreSQLAdapter)
        t.jsonb "payload"
      else
        t.json "payload"
      end
    end

    ActiveRecord::Base.lease_connection.enable_query_cache!
  end

  def test_query_cache_handles_mutated_binds
    JsonObj.create(payload: ObjectFixedHash.new({ a: 1 }))

    search = ObjectFixedHash.new({ a: 1 })
    JsonObj.where(payload: search).first # populate the cache

    search.b = 2
    assert_nil JsonObj.where(payload: search).first, "cache returned a false positive"
  end

  def teardown
    ActiveRecord::Base.lease_connection.disable_query_cache!
    ActiveRecord::Base.lease_connection.drop_table("json_objs", if_exists: true)
  end
end

class QuerySerializedParamTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  fixtures :topics

  class YAMLObj < ActiveRecord::Base
    self.table_name = "yaml_objs"

    serialize :payload
  end

  def setup
    @use_yaml_unsafe_load_was = ActiveRecord.use_yaml_unsafe_load

    ActiveRecord::Base.lease_connection.create_table("yaml_objs", force: true) do |t|
      t.text "payload"
    end

    ActiveRecord::Base.lease_connection.enable_query_cache!
  end

  def teardown
    ActiveRecord::Base.lease_connection.disable_query_cache!
    ActiveRecord::Base.lease_connection.drop_table("yaml_objs", if_exists: true)

    ActiveRecord.use_yaml_unsafe_load = @use_yaml_unsafe_load_was
  end

  def test_query_serialized_active_record
    ActiveRecord.use_yaml_unsafe_load = true

    topic = Topic.first
    assert_not_nil topic

    obj = YAMLObj.create!(payload: { topic: topic })

    # This is absolutely terrible, no-one should ever do this
    assert_equal obj, YAMLObj.where(payload: { topic: topic }).first

    relation = YAMLObj.where(payload: { topic: topic })
    topic.title = "New Title"
    assert_equal obj, relation.first

    assert_nil YAMLObj.where(payload: { topic: topic }).first
  end

  def test_query_serialized_string
    ActiveRecord.use_yaml_unsafe_load = false

    obj = YAMLObj.create!(payload: "payload")
    assert_equal obj, YAMLObj.find_by!(payload: "payload")
  end
end

class QueryCacheExpiryTest < ActiveRecord::TestCase
  fixtures :tasks, :posts, :categories, :categories_posts

  def teardown
    Task.lease_connection.clear_query_cache
  end

  def test_cache_gets_cleared_after_migration
    # warm the cache
    Post.find(1)

    # change the column definition
    Post.lease_connection.change_column :posts, :title, :string, limit: 80
    assert_nothing_raised { Post.find(1) }

    # restore the old definition
    Post.lease_connection.change_column :posts, :title, :string
  end

  def test_find
    assert_called(Task.connection_pool.query_cache, :clear, times: 1) do
      assert_not Task.connection_pool.query_cache_enabled
      Task.cache do
        assert Task.connection_pool.query_cache_enabled
        Task.find(1)

        Task.uncached do
          assert_not Task.connection_pool.query_cache_enabled
          Task.find(1)
        end

        assert Task.connection_pool.query_cache_enabled
      end
      assert_not Task.connection_pool.query_cache_enabled
    end
  end

  def test_enable_disable
    assert_called(Task.connection_pool.query_cache, :clear, times: 1) do
      Task.cache { }
    end

    assert_called(Task.connection_pool.query_cache, :clear, times: 1) do
      Task.cache { Task.cache { } }
    end
  end

  def test_update
    Task.cache do
      assert_called(Task.connection_pool.query_cache, :clear, times: 1) do
        task = Task.find(1)
        task.starting = Time.now.utc
        task.save!
      end
    end
  end

  def test_destroy
    Task.cache do
      assert_called(Task.connection_pool.query_cache, :clear, times: 1) do
        Task.find(1).destroy
      end
    end
  end

  def test_insert
    Task.cache do
      assert_called(ActiveRecord::Base.connection_pool.query_cache, :clear, times: 1) do
        Task.create!
      end
    end
  end

  def test_insert_all
    skip unless supports_insert_on_duplicate_skip?

    Task.cache do
      assert_called(ActiveRecord::Base.connection_pool.query_cache, :clear, times: 1) do
        Task.insert({ starting: Time.now })
      end

      assert_called(ActiveRecord::Base.connection_pool.query_cache, :clear, times: 1) do
        Task.insert_all([{ starting: Time.now }])
      end
    end
  end

  def test_insert_all_bang
    Task.cache do
      assert_called(ActiveRecord::Base.connection_pool.query_cache, :clear, times: 1) do
        Task.insert!({ starting: Time.now })
      end

      assert_called(ActiveRecord::Base.connection_pool.query_cache, :clear, times: 1) do
        Task.insert_all!([{ starting: Time.now }])
      end
    end
  end

  def test_upsert_all
    skip unless supports_insert_on_duplicate_update?

    Task.cache do
      assert_called(ActiveRecord::Base.connection_pool.query_cache, :clear, times: 1) do
        Task.upsert({ starting: Time.now })
      end

      assert_called(ActiveRecord::Base.connection_pool.query_cache, :clear, times: 1) do
        Task.upsert_all([{ starting: Time.now }])
      end
    end
  end

  def test_cache_is_expired_by_habtm_update
    ActiveRecord::Base.cache do
      assert_called(ActiveRecord::Base.connection_pool.query_cache, :clear, times: 1) do
        c = Category.first
        p = Post.first
        p.categories << c
      end
    end
  end

  def test_cache_is_expired_by_habtm_delete
    ActiveRecord::Base.cache do
      assert_called(ActiveRecord::Base.connection_pool.query_cache, :clear, times: 1) do
        p = Post.find(1)
        assert_predicate p.categories, :any?
        p.categories.delete_all
      end
    end
  end

  def test_query_cache_lru_eviction
    store = ActiveRecord::ConnectionAdapters::QueryCache::Store.new(Concurrent::AtomicFixnum.new, 2)
    store.enabled = true

    connection = Post.lease_connection
    old_store, connection.query_cache = connection.query_cache, store
    begin
      Post.cache do
        assert_queries_count(2) do
          connection.select_all("SELECT 1")
          connection.select_all("SELECT 2")
          connection.select_all("SELECT 1")
        end

        assert_queries_count(1) do
          connection.select_all("SELECT 3")
          connection.select_all("SELECT 3")
        end

        assert_no_queries do
          connection.select_all("SELECT 1")
        end

        assert_queries_count(1) do
          connection.select_all("SELECT 2")
        end
      end
    ensure
      connection.query_cache = old_store
    end
  end

  test "threads use the same connection" do
    @connection_1 = ActiveRecord::Base.lease_connection.object_id

    thread_a = Thread.new do
      @connection_2 = ActiveRecord::Base.lease_connection.object_id
    end

    thread_a.join

    assert_equal @connection_1, @connection_2
  end
end

class TransactionInCachedSqlActiveRecordPayloadTest < ActiveRecord::TestCase
  # We need current_transaction to return the null transaction.
  self.use_transactional_tests = false

  def test_payload_without_open_transaction
    asserted = false

    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
      if event.payload[:cached]
        assert_nil event.payload.fetch(:transaction)
        asserted = true
      end
    end
    Task.cache do
      2.times { Task.count }
    end

    assert asserted
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  def test_payload_with_open_transaction
    asserted = false
    expected_transaction = nil

    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
      if event.payload[:cached]
        assert_same expected_transaction, event.payload[:transaction]
        asserted = true
      end
    end

    Task.transaction do |transaction|
      expected_transaction = transaction

      Task.cache do
        2.times { Task.count }
      end
    end

    assert asserted
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
