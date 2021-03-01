# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

module ActiveRecord
  class LoadAsyncTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    fixtures :posts, :comments

    def test_scheduled?
      defered_posts = Post.where(author_id: 1).load_async
      if in_memory_db?
        assert_not_predicate defered_posts, :scheduled?
      else
        assert_predicate defered_posts, :scheduled?
      end
      assert_predicate defered_posts, :loaded?
      defered_posts.to_a
      assert_not_predicate defered_posts, :scheduled?
    end

    def test_reset
      defered_posts = Post.where(author_id: 1).load_async
      if in_memory_db?
        assert_not_predicate defered_posts, :scheduled?
      else
        assert_predicate defered_posts, :scheduled?
      end
      defered_posts.reset
      assert_not_predicate defered_posts, :scheduled?
    end

    def test_simple_query
      expected_records = Post.where(author_id: 1).to_a

      status = {}
      monitor = Monitor.new
      condition = monitor.new_cond

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
        if event.payload[:name] == "Post Load"
          status[:executed] = true
          status[:async] = event.payload[:async]
          monitor.synchronize { condition.signal }
        end
      end

      defered_posts = Post.where(author_id: 1).load_async

      monitor.synchronize do
        condition.wait_until { status[:executed] }
      end

      assert_equal expected_records, defered_posts.to_a
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
      monitor = Monitor.new
      condition = monitor.new_cond

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
        if event.payload[:name] == "SQL"
          status[:executed] = true
          status[:async] = event.payload[:async]
          monitor.synchronize { condition.signal }
        end
      end

      defered_posts = Post.where(author_id: 1).eager_load(:comments).load_async

      if in_memory_db?
        assert_not_predicate defered_posts, :scheduled?
      else
        assert_predicate defered_posts, :scheduled?
      end

      monitor.synchronize do
        condition.wait_until { status[:executed] }
      end

      assert_equal expected_records, defered_posts.to_a
      assert_queries(0) do
        defered_posts.each(&:comments)
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

      defered_posts = Post.where(author_id: 1).load_async

      assert_equal expected_size, defered_posts.size
      assert_predicate defered_posts, :loaded?
    end

    def test_empty?
      defered_posts = Post.where(author_id: 1).load_async

      assert_equal false, defered_posts.empty?
      assert_predicate defered_posts, :loaded?
    end
  end

  unless in_memory_db?
    class LoadAsyncNullExecutorTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      fixtures :posts, :comments

      def setup
        @old_config = ActiveRecord::Base.async_query_executor
        ActiveRecord::Base.async_query_executor = nil
        ActiveRecord::Base.establish_connection :arunit
      end

      def teardown
        ActiveRecord::Base.async_query_executor = @old_config
        ActiveRecord::Base.establish_connection :arunit
      end

      def test_scheduled?
        defered_posts = Post.where(author_id: 1).load_async
        assert_not_predicate defered_posts, :scheduled?
        assert_predicate defered_posts, :loaded?
        defered_posts.to_a
        assert_not_predicate defered_posts, :scheduled?
      end

      def test_reset
        defered_posts = Post.where(author_id: 1).load_async
        assert_not_predicate defered_posts, :scheduled?
        defered_posts.reset
        assert_not_predicate defered_posts, :scheduled?
      end

      def test_simple_query
        expected_records = Post.where(author_id: 1).to_a

        status = {}
        monitor = Monitor.new
        condition = monitor.new_cond

        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
          if event.payload[:name] == "Post Load"
            status[:executed] = true
            status[:async] = event.payload[:async]
            monitor.synchronize { condition.signal }
          end
        end

        defered_posts = Post.where(author_id: 1).load_async

        monitor.synchronize do
          condition.wait_until { status[:executed] }
        end

        assert_equal expected_records, defered_posts.to_a
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
        monitor = Monitor.new
        condition = monitor.new_cond

        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
          if event.payload[:name] == "SQL"
            status[:executed] = true
            status[:async] = event.payload[:async]
            monitor.synchronize { condition.signal }
          end
        end

        defered_posts = Post.where(author_id: 1).eager_load(:comments).load_async

        assert_not_predicate defered_posts, :scheduled?

        monitor.synchronize do
          condition.wait_until { status[:executed] }
        end

        assert_equal expected_records, defered_posts.to_a
        assert_queries(0) do
          defered_posts.each(&:comments)
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

        defered_posts = Post.where(author_id: 1).load_async

        assert_equal expected_size, defered_posts.size
        assert_predicate defered_posts, :loaded?
      end

      def test_empty?
        defered_posts = Post.where(author_id: 1).load_async

        assert_equal false, defered_posts.empty?
        assert_predicate defered_posts, :loaded?
      end
    end
  end
end
