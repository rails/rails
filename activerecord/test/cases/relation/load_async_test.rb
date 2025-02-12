# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/category"
require "models/comment"
require "models/other_dog"
require "concurrent/atomic/count_down_latch"

module ActiveRecord
  class LoadAsyncTest < ActiveRecord::TestCase
    include WaitForAsyncTestHelper

    fixtures :posts, :comments, :categories, :categories_posts

    def test_scheduled?
      deferred_posts = Post.where(author_id: 1).load_async
      if in_memory_db?
        assert_not_predicate deferred_posts, :scheduled?
      else
        assert_predicate deferred_posts, :scheduled?
      end
      assert_predicate deferred_posts, :loaded?
      deferred_posts.to_a
      assert_not_predicate deferred_posts, :scheduled?
    end

    def test_null_scheduled?
      deferred_null_posts = Post.none.load_async
      if in_memory_db?
        assert_not_predicate deferred_null_posts, :scheduled?
      else
        assert_predicate deferred_null_posts, :scheduled?
      end
      assert_predicate deferred_null_posts, :loaded?
      deferred_null_posts.to_a
      assert_not_predicate deferred_null_posts, :scheduled?
    end

    def test_reset
      deferred_posts = Post.where(author_id: 1).load_async
      if in_memory_db?
        assert_not_predicate deferred_posts, :scheduled?
      else
        assert_predicate deferred_posts, :scheduled?
      end
      deferred_posts.reset
      assert_not_predicate deferred_posts, :scheduled?
    end

    unless in_memory_db?
      def test_load_async_has_many_association
        post = Post.first

        defered_comments = post.comments.load_async
        assert_predicate defered_comments, :scheduled?

        events = []
        callback = -> (event) do
          events << event unless event.payload[:name] == "SCHEMA"
        end

        wait_for_async_query
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          defered_comments.to_a
        end

        assert_equal [["Comment Load", true]], events.map { |e| [e.payload[:name], e.payload[:async]] }
        assert_not_predicate post.comments, :loaded?
      end

      def test_load_async_has_many_through_association
        post = Post.first

        defered_categories = post.scategories.load_async
        assert_predicate defered_categories, :scheduled?

        events = []
        callback = -> (event) do
          events << event unless event.payload[:name] == "SCHEMA"
        end

        wait_for_async_query
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          defered_categories.to_a
        end

        assert_equal [["Category Load", true]], events.map { |e| [e.payload[:name], e.payload[:async]] }
        assert_not_predicate post.scategories, :loaded?
      end
    end

    def test_notification_forwarding
      expected_records = Post.where(author_id: 1).to_a

      status = {}

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
        if event.payload[:name] == "Post Load"
          status[:executed] = true
          status[:async] = event.payload[:async]
          status[:thread_id] = Thread.current.object_id
          status[:lock_wait] = event.payload[:lock_wait]
        end
      end

      deferred_posts = Post.where(author_id: 1).load_async
      wait_for_async_query

      assert_equal expected_records, deferred_posts.to_a
      assert_equal Post.lease_connection.supports_concurrent_connections?, status[:async]
      assert_equal Thread.current.object_id, status[:thread_id]
      if Post.lease_connection.supports_concurrent_connections?
        assert_instance_of Float, status[:lock_wait]
      else
        assert_nil status[:lock_wait]
      end
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_simple_query
      expected_records = Post.where(author_id: 1).to_a

      status = {}

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
        if event.payload[:name] == "Post Load"
          status[:executed] = true
          status[:async] = event.payload[:async]
        end
      end

      deferred_posts = Post.where(author_id: 1).load_async
      wait_for_async_query

      assert_equal expected_records, deferred_posts.to_a
      assert_equal Post.lease_connection.supports_concurrent_connections?, status[:async]
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_load_async_from_transaction
      posts = nil
      Post.transaction do
        Post.where(author_id: 1).update_all(title: "In Transaction")
        posts = Post.where(author_id: 1).load_async
        if in_memory_db?
          assert_not_predicate posts, :scheduled?
        else
          assert_predicate posts, :scheduled?
        end
        assert_predicate posts, :loaded?
        raise ActiveRecord::Rollback
      end

      assert_not_nil posts
      assert_equal ["In Transaction"], posts.map(&:title).uniq
    end

    def test_load_async_instrumentation_is_thread_safe
      skip unless ActiveRecord::Base.connection.async_enabled?

      begin
        latch1 = Concurrent::CountDownLatch.new
        latch2 = Concurrent::CountDownLatch.new

        old_log = ActiveRecord::Base.connection.method(:log)
        ActiveRecord::Base.connection.singleton_class.undef_method(:log)

        ActiveRecord::Base.connection.singleton_class.define_method(:log) do |*args, **kwargs, &block|
          unless kwargs[:async]
            return old_log.call(*args, **kwargs, &block)
          end

          latch1.count_down
          latch2.wait
          old_log.call(*args, **kwargs, &block)
        end

        Post.async_count
        latch1.wait

        notification_called = false
        ActiveSupport::Notifications.subscribed(->(*) { notification_called = true }, "sql.active_record") do
          Post.count
        end

        assert(notification_called)
      ensure
        latch2.count_down
        ActiveRecord::Base.connection.singleton_class.undef_method(:log)
        ActiveRecord::Base.connection.singleton_class.define_method(:log, old_log)
      end
    end

    def test_eager_loading_query
      expected_records = Post.where(author_id: 1).eager_load(:comments).to_a

      status = {}

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
        if event.payload[:name] == "Post Eager Load"
          status[:executed] = true
          status[:async] = event.payload[:async]
        end
      end

      deferred_posts = Post.where(author_id: 1).eager_load(:comments).load_async
      wait_for_async_query

      if in_memory_db?
        assert_not_predicate deferred_posts, :scheduled?
      else
        assert_predicate deferred_posts, :scheduled?
      end

      assert_equal expected_records, deferred_posts.to_a
      assert_queries_count(0) do
        deferred_posts.each(&:comments)
      end
      assert_equal Post.lease_connection.supports_concurrent_connections?, status[:async]
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_contradiction
      assert_queries_count(0) do
        assert_equal [], Post.where(id: []).load_async.to_a
      end

      Post.where(id: []).load_async.reset
    end

    def test_pluck
      titles = Post.where(author_id: 1).pluck(:title)
      assert_equal titles, Post.where(author_id: 1).load_async.pluck(:title)
    end

    def test_count
      count = Post.where(author_id: 1).count
      assert_equal count, Post.where(author_id: 1).load_async.count
    end

    def test_size
      expected_size = Post.where(author_id: 1).size

      deferred_posts = Post.where(author_id: 1).load_async

      assert_equal expected_size, deferred_posts.size
      assert_predicate deferred_posts, :loaded?
    end

    def test_empty?
      deferred_posts = Post.where(author_id: 1).load_async

      assert_equal false, deferred_posts.empty?
      assert_predicate deferred_posts, :loaded?
    end

    def test_load_async_pluck_with_query_cache
      titles = Post.where(author_id: 1).pluck(:title)
      Post.cache do
        assert_equal titles, Post.where(author_id: 1).load_async.pluck(:title)
      end
    end

    def test_load_async_count_with_query_cache
      count = Post.where(author_id: 1).count
      Post.cache do
        assert_equal count, Post.where(author_id: 1).load_async.count
      end
    end
  end

  class LoadAsyncNullExecutorTest < ActiveRecord::TestCase
    unless in_memory_db?
      fixtures :posts, :comments

      def setup
        @old_config = ActiveRecord.async_query_executor
        ActiveRecord.async_query_executor = nil
      end

      def teardown
        ActiveRecord.async_query_executor = @old_config
      end

      def test_scheduled?
        deferred_posts = Post.where(author_id: 1).load_async
        assert_not_predicate deferred_posts, :scheduled?
        assert_predicate deferred_posts, :loaded?
        deferred_posts.to_a
        assert_not_predicate deferred_posts, :scheduled?
      end

      def test_reset
        deferred_posts = Post.where(author_id: 1).load_async
        assert_not_predicate deferred_posts, :scheduled?
        deferred_posts.reset
        assert_not_predicate deferred_posts, :scheduled?
      end

      def test_simple_query
        expected_records = Post.where(author_id: 1).to_a

        status = {}

        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
          if event.payload[:name] == "Post Load"
            status[:executed] = true
            status[:async] = event.payload[:async]
          end
        end

        deferred_posts = Post.where(author_id: 1).load_async

        assert_equal expected_records, deferred_posts.to_a
        assert_not_equal Post.lease_connection.supports_concurrent_connections?, status[:async]
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end

      def test_load_async_from_transaction
        posts = nil
        Post.transaction do
          Post.where(author_id: 1).update_all(title: "In Transaction")
          posts = Post.where(author_id: 1).load_async
          assert_not_predicate posts, :scheduled?
          assert_predicate posts, :loaded?
          raise ActiveRecord::Rollback
        end

        assert_not_nil posts
        assert_equal ["In Transaction"], posts.map(&:title).uniq
      end

      def test_eager_loading_query
        expected_records = Post.where(author_id: 1).eager_load(:comments).to_a

        status = {}

        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
          if event.payload[:name] == "SQL"
            status[:executed] = true
            status[:async] = event.payload[:async]
          end
        end

        deferred_posts = Post.where(author_id: 1).eager_load(:comments).load_async

        assert_not_predicate deferred_posts, :scheduled?

        assert_equal expected_records, deferred_posts.to_a
        assert_queries_count(0) do
          deferred_posts.each(&:comments)
        end

        assert_predicate Post.lease_connection, :supports_concurrent_connections?
        assert_not status[:async], "Expected status[:async] to be false with NullExecutor"
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end

      def test_contradiction
        assert_queries_count(0) do
          assert_equal [], Post.where(id: []).load_async.to_a
        end

        Post.where(id: []).load_async.reset
      end

      def test_pluck
        titles = Post.where(author_id: 1).pluck(:title)
        assert_equal titles, Post.where(author_id: 1).load_async.pluck(:title)
      end

      def test_size
        expected_size = Post.where(author_id: 1).size

        deferred_posts = Post.where(author_id: 1).load_async

        assert_equal expected_size, deferred_posts.size
        assert_predicate deferred_posts, :loaded?
      end

      def test_empty?
        deferred_posts = Post.where(author_id: 1).load_async

        assert_equal false, deferred_posts.empty?
        assert_predicate deferred_posts, :loaded?
      end
    end
  end

  class LoadAsyncMultiThreadPoolExecutorTest < ActiveRecord::TestCase
    unless in_memory_db?
      include WaitForAsyncTestHelper

      fixtures :posts, :comments

      def setup
        @old_config = ActiveRecord.async_query_executor
        ActiveRecord.async_query_executor = :multi_thread_pool

        config_hash1 = ActiveRecord::Base.connection_pool.db_config.configuration_hash.merge(min_threads: 0, max_threads: 10)
        config_hash2 = ARUnit2Model.connection_pool.db_config.configuration_hash.merge(min_threads: 0, max_threads: 10)

        ActiveRecord::Base.establish_connection(config_hash1)
        ARUnit2Model.establish_connection(config_hash2)
      end

      def teardown
        ActiveRecord.async_query_executor = @old_config
        clean_up_connection_handler
        ActiveRecord::Base.establish_connection(:arunit)
        ARUnit2Model.establish_connection(:arunit2)
      end

      def test_async_query_executor_and_configuration
        assert_equal :multi_thread_pool, ActiveRecord.async_query_executor

        assert_equal 0, ActiveRecord::Base.connection_pool.db_config.configuration_hash[:min_threads]
        assert_equal 0, ARUnit2Model.connection_pool.db_config.configuration_hash[:min_threads]

        assert_equal 10, ActiveRecord::Base.connection_pool.db_config.configuration_hash[:max_threads]
        assert_equal 10, ARUnit2Model.connection_pool.db_config.configuration_hash[:max_threads]
      end

      def test_scheduled?
        deferred_posts = Post.where(author_id: 1).load_async
        assert_predicate deferred_posts, :scheduled?
        assert_predicate deferred_posts, :loaded?
        deferred_posts.to_a
        assert_not_predicate deferred_posts, :scheduled?
      end

      def test_reset
        deferred_posts = Post.where(author_id: 1).load_async
        assert_predicate deferred_posts, :scheduled?
        deferred_posts.reset
        assert_not_predicate deferred_posts, :scheduled?
      end

      def test_simple_query
        expected_records = Post.where(author_id: 1).to_a

        status = {}
        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
          if event.payload[:name] == "Post Load"
            status[:executed] = true
            status[:async] = event.payload[:async]
          end
        end

        deferred_posts = Post.where(author_id: 1).load_async
        wait_for_async_query

        assert_equal expected_records, deferred_posts.to_a
        assert_equal Post.lease_connection.supports_concurrent_connections?, status[:async]
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end

      def test_load_async_from_transaction
        posts = nil
        Post.transaction do
          Post.where(author_id: 1).update_all(title: "In Transaction")
          posts = Post.where(author_id: 1).load_async
          assert_predicate posts, :scheduled?
          assert_predicate posts, :loaded?
          raise ActiveRecord::Rollback
        end

        assert_not_nil posts
        assert_equal ["In Transaction"], posts.map(&:title).uniq
      end

      def test_eager_loading_query
        expected_records = Post.where(author_id: 1).eager_load(:comments).to_a

        status = {}
        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
          if event.payload[:name] == "Post Eager Load"
            status[:executed] = true
            status[:async] = event.payload[:async]
          end
        end

        deferred_posts = Post.where(author_id: 1).eager_load(:comments).load_async
        wait_for_async_query

        assert_predicate deferred_posts, :scheduled?

        assert_equal expected_records, deferred_posts.to_a
        assert_queries_count(0) do
          deferred_posts.each(&:comments)
        end
        assert_equal Post.lease_connection.supports_concurrent_connections?, status[:async]
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end

      def test_contradiction
        assert_queries_count(0) do
          assert_equal [], Post.where(id: []).load_async.to_a
        end

        Post.where(id: []).load_async.reset
      end

      def test_pluck
        titles = Post.where(author_id: 1).pluck(:title)
        assert_equal titles, Post.where(author_id: 1).load_async.pluck(:title)
      end

      def test_size
        expected_size = Post.where(author_id: 1).size

        deferred_posts = Post.where(author_id: 1).load_async

        assert_equal expected_size, deferred_posts.size
        assert_predicate deferred_posts, :loaded?
      end

      def test_empty?
        deferred_posts = Post.where(author_id: 1).load_async

        assert_equal false, deferred_posts.empty?
        assert_predicate deferred_posts, :loaded?
      end
    end
  end

  class LoadAsyncMixedThreadPoolExecutorTest < ActiveRecord::TestCase
    unless in_memory_db?
      include WaitForAsyncTestHelper

      fixtures :posts, :comments, :other_dogs

      def setup
        @previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"
        @old_config = ActiveRecord.async_query_executor
        ActiveRecord.async_query_executor = :multi_thread_pool
        config_hash1 = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary").configuration_hash
        config_hash2 = ActiveRecord::Base.configurations.configs_for(env_name: "arunit2", name: "primary").configuration_hash
        config = {
          "default_env" => {
            "animals" => config_hash2.merge({ min_threads: 0, max_threads: 0 }),
            "primary" => config_hash1.merge({ min_threads: 0, max_threads: 10 })
          }
        }
        @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

        ActiveRecord::Base.establish_connection(:primary)
        ARUnit2Model.establish_connection(:animals)
      end

      def teardown
        ENV["RAILS_ENV"] = @previous_env
        ActiveRecord::Base.configurations = @prev_configs
        ActiveRecord.async_query_executor = @old_config
        clean_up_connection_handler
      end

      def test_scheduled?
        deferred_posts = Post.where(author_id: 1).load_async
        assert_predicate deferred_posts, :scheduled?
        assert_predicate deferred_posts, :loaded?
        deferred_posts.to_a
        assert_not_predicate deferred_posts, :scheduled?

        deferred_dogs = OtherDog.where(id: 1).load_async
        assert_not_predicate deferred_dogs, :scheduled?
        assert_predicate deferred_dogs, :loaded?
      end

      def test_simple_query
        expected_records = Post.where(author_id: 1).to_a
        expected_dogs = OtherDog.where(id: 1).to_a

        status = {}
        dog_status = {}

        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
          if event.payload[:name] == "Post Load"
            status[:executed] = true
            status[:async] = event.payload[:async]
          end

          if event.payload[:name] == "OtherDog Load"
            dog_status[:executed] = true
            dog_status[:async] = event.payload[:async]
          end
        end

        deferred_posts = Post.where(author_id: 1).load_async
        deferred_dogs = OtherDog.where(id: 1).load_async

        wait_for_async_query
        wait_for_async_query

        assert_equal expected_records, deferred_posts.to_a
        assert_equal expected_dogs, deferred_dogs.to_a

        assert_equal Post.lease_connection.async_enabled?, status[:async]
        assert_equal OtherDog.lease_connection.async_enabled?, dog_status[:async]
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end
    end
  end
end
