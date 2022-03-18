# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"
require "models/other_dog"

module ActiveRecord
  module WaitForAsyncTestHelper
    private
      def wait_for_async_query(relation, timeout: 5)
        if !relation.connection.async_enabled? || relation.instance_variable_get(:@records)
          return relation
        end

        future_result = relation.instance_variable_get(:@future_result)
        (timeout * 100).times do
          return relation unless future_result.pending?
          sleep 0.01
        end
        raise Timeout::Error, "The async executor wasn't drained after #{timeout} seconds"
      end
  end

  class LoadAsyncTest < ActiveRecord::TestCase
    include WaitForAsyncTestHelper

    self.use_transactional_tests = false

    fixtures :posts, :comments

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

      deferred_posts = wait_for_async_query(Post.where(author_id: 1).load_async)

      assert_equal expected_records, deferred_posts.to_a
      assert_equal Post.connection.supports_concurrent_connections?, status[:async]
      assert_equal Thread.current.object_id, status[:thread_id]
      if Post.connection.supports_concurrent_connections?
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

      deferred_posts = wait_for_async_query(Post.where(author_id: 1).load_async)

      assert_equal expected_records, deferred_posts.to_a
      assert_equal Post.connection.supports_concurrent_connections?, status[:async]
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

    def test_eager_loading_query
      expected_records = Post.where(author_id: 1).eager_load(:comments).to_a

      status = {}

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
        if event.payload[:name] == "SQL"
          status[:executed] = true
          status[:async] = event.payload[:async]
        end
      end

      deferred_posts = wait_for_async_query(Post.where(author_id: 1).eager_load(:comments).load_async)

      if in_memory_db?
        assert_not_predicate deferred_posts, :scheduled?
      else
        assert_predicate deferred_posts, :scheduled?
      end

      assert_equal expected_records, deferred_posts.to_a
      assert_queries(0) do
        deferred_posts.each(&:comments)
      end
      assert_equal Post.connection.supports_concurrent_connections?, status[:async]
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_contradiction
      assert_queries(0) do
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

  unless in_memory_db?
    class LoadAsyncNullExecutorTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      fixtures :posts, :comments

      def setup
        @old_config = ActiveRecord.async_query_executor
        ActiveRecord.async_query_executor = nil
        ActiveRecord::Base.establish_connection :arunit
      end

      def teardown
        ActiveRecord.async_query_executor = @old_config
        ActiveRecord::Base.establish_connection :arunit
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
        assert_not_equal Post.connection.supports_concurrent_connections?, status[:async]
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
        assert_queries(0) do
          deferred_posts.each(&:comments)
        end

        assert_predicate Post.connection, :supports_concurrent_connections?
        assert_not status[:async], "Expected status[:async] to be false with NullExecutor"
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end

      def test_contradiction
        assert_queries(0) do
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

    class LoadAsyncMultiThreadPoolExecutorTest < ActiveRecord::TestCase
      include WaitForAsyncTestHelper

      self.use_transactional_tests = false

      fixtures :posts, :comments

      def setup
        @old_config = ActiveRecord.async_query_executor
        ActiveRecord.async_query_executor = :multi_thread_pool

        handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
        config_hash1 = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary").configuration_hash
        new_config1 = config_hash1.merge(min_threads: 0, max_threads: 10)
        db_config1 = ActiveRecord::DatabaseConfigurations::HashConfig.new("arunit", "primary", new_config1)

        config_hash2 = ActiveRecord::Base.configurations.configs_for(env_name: "arunit2", name: "primary").configuration_hash
        new_config2 = config_hash2.merge(min_threads: 0, max_threads: 10)
        db_config2 = ActiveRecord::DatabaseConfigurations::HashConfig.new("arunit2", "primary", new_config2)

        handler.establish_connection(db_config1)
        handler.establish_connection(db_config2, owner_name: ARUnit2Model)
      end

      def teardown
        ActiveRecord.async_query_executor = @old_config
        clean_up_connection_handler
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

        deferred_posts = wait_for_async_query(Post.where(author_id: 1).load_async)

        assert_equal expected_records, deferred_posts.to_a
        assert_equal Post.connection.supports_concurrent_connections?, status[:async]
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
          if event.payload[:name] == "SQL"
            status[:executed] = true
            status[:async] = event.payload[:async]
          end
        end

        deferred_posts = wait_for_async_query(Post.where(author_id: 1).eager_load(:comments).load_async)

        assert_predicate deferred_posts, :scheduled?

        assert_equal expected_records, deferred_posts.to_a
        assert_queries(0) do
          deferred_posts.each(&:comments)
        end
        assert_equal Post.connection.supports_concurrent_connections?, status[:async]
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end

      def test_contradiction
        assert_queries(0) do
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

    class LoadAsyncMixedThreadPoolExecutorTest < ActiveRecord::TestCase
      include WaitForAsyncTestHelper

      self.use_transactional_tests = false

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

        wait_for_async_query(deferred_posts)
        wait_for_async_query(deferred_dogs)

        assert_equal expected_records, deferred_posts.to_a
        assert_equal expected_dogs, deferred_dogs.to_a

        assert_equal Post.connection.async_enabled?, status[:async]
        assert_equal OtherDog.connection.async_enabled?, dog_status[:async]
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end
    end
  end
end
