# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/reply"
require "models/author"
require "models/post"

if ActiveRecord::Base.lease_connection.prepared_statements
  module ActiveRecord
    class BindParameterTest < ActiveRecord::TestCase
      fixtures :topics, :authors, :author_addresses, :posts

      class LogListener
        attr_accessor :calls

        def initialize
          @calls = []
        end

        def call(*args)
          calls << args
        end
      end

      def setup
        super
        @connection = ActiveRecord::Base.lease_connection
        @subscriber = LogListener.new
        @subscription = ActiveSupport::Notifications.subscribe("sql.active_record", @subscriber)
      end

      def teardown
        ActiveSupport::Notifications.unsubscribe(@subscription)
      end

      def test_statement_cache
        @connection.clear_cache!

        topics = Topic.where(id: 1)
        assert_equal [1], topics.map(&:id)
        assert_includes statement_cache, to_sql_key(topics.arel)

        @connection.clear_cache!

        assert_not_includes statement_cache, to_sql_key(topics.arel)
      end

      def test_statement_cache_with_query_cache
        @connection.enable_query_cache!
        @connection.clear_cache!

        topics = Topic.where(id: 1)
        assert_equal [1], topics.map(&:id)
        assert_includes statement_cache, to_sql_key(topics.arel)
      ensure
        @connection.disable_query_cache!
      end

      def test_statement_cache_with_find
        @connection.clear_cache!

        assert_equal 1, Topic.find(1).id
        assert_raises(RecordNotFound) { SillyReply.find(2) }

        topic_sql = cached_statement(Topic, [Topic.primary_key])
        assert_includes statement_cache, to_sql_key(topic_sql)

        reply_sql = cached_statement(SillyReply, [SillyReply.primary_key])
        assert_includes statement_cache, to_sql_key(reply_sql)

        replies = SillyReply.where(id: 2).limit(1)
        assert_includes statement_cache, to_sql_key(replies.arel)
      end

      def test_statement_cache_with_find_by
        @connection.clear_cache!

        assert_equal 1, Topic.find_by!(id: 1).id
        assert_raises(RecordNotFound) { SillyReply.find_by!(id: 2) }

        topic_sql = cached_statement(Topic, ["id"])
        assert_includes statement_cache, to_sql_key(topic_sql)

        reply_sql = cached_statement(SillyReply, ["id"])
        assert_includes statement_cache, to_sql_key(reply_sql)

        replies = SillyReply.where(id: 2).limit(1)
        assert_includes statement_cache, to_sql_key(replies.arel)
      end

      def test_statement_cache_with_in_clause
        @connection.clear_cache!

        topics = Topic.where(id: [1, 3]).order(:id)
        assert_equal [1, 3], topics.map(&:id)
        assert_not_includes statement_cache, to_sql_key(topics.arel)
      end

      def test_statement_cache_with_sql_string_literal
        @connection.clear_cache!

        topics = Topic.where("topics.id = ?", 1)
        assert_equal [1], topics.map(&:id)
        assert_includes statement_cache, to_sql_key(topics.arel)
      end

      def test_too_many_binds
        bind_params_length = @connection.send(:bind_params_length)

        topics = Topic.where(id: (1 .. bind_params_length).to_a << 2**63)
        assert_equal Topic.count, topics.count

        topics = Topic.where.not(id: (1 .. bind_params_length).to_a << 2**63)
        assert_equal 0, topics.count
      end

      def test_too_many_binds_with_query_cache
        @connection.enable_query_cache!

        bind_params_length = @connection.send(:bind_params_length)
        topics = Topic.where(id: (1 .. bind_params_length + 1).to_a)
        assert_equal Topic.count, topics.count

        topics = Topic.where.not(id: (1 .. bind_params_length + 1).to_a)
        assert_equal 0, topics.count
      ensure
        @connection.disable_query_cache!
      end

      def test_bind_from_join_in_subquery
        subquery = Author.joins(:thinking_posts).where(name: "David")
        scope = Author.from(subquery, "authors").where(id: 1)
        assert_equal 1, scope.count
      end

      def test_binds_are_logged
        sub   = Arel::Nodes::BindParam.new(1)
        binds = [Relation::QueryAttribute.new("id", 1, Type::Value.new)]
        sql   = "select * from topics where id = #{sub.to_sql}"

        @connection.exec_query(sql, "SQL", binds)

        message = @subscriber.calls.find { |args| args[4][:sql] == sql }
        assert_equal binds, message[4][:binds]
      end

      def test_find_one_uses_binds
        Topic.find(1)
        message = @subscriber.calls.find { |args| args[4][:binds].any? { |attr| attr.value == 1 } }
        assert message, "expected a message with binds"
      end

      def test_logs_binds_after_type_cast
        binds = [Relation::QueryAttribute.new("id", "10", Type::Integer.new)]
        assert_logs_binds(binds)
      end

      def test_logs_unnamed_binds
        binds = ["abcd"]
        assert_logs_unnamed_binds(binds)
      end

      def test_bind_params_to_sql_with_prepared_statements
        assert_bind_params_to_sql
      end

      def test_bind_params_to_sql_with_unprepared_statements
        @connection.unprepared_statement do
          assert_bind_params_to_sql
        end
      end

      def test_nested_unprepared_statements
        assert_predicate @connection, :prepared_statements?

        @connection.unprepared_statement do
          assert_not_predicate @connection, :prepared_statements?

          @connection.unprepared_statement do
            assert_not_predicate @connection, :prepared_statements?
          end

          assert_not_predicate @connection, :prepared_statements?
        end

        assert_predicate @connection, :prepared_statements?
      end

      def test_binds_with_filtered_attributes
        ActiveRecord::Base.filter_attributes = [:auth]

        binds = [Relation::QueryAttribute.new("auth_token", "abcd", Type::String.new)]

        assert_filtered_log_binds(binds)

        ActiveRecord::Base.filter_attributes = []
      end

      private
        def assert_bind_params_to_sql
          table = Author.quoted_table_name
          pk = "#{table}.#{Author.quoted_primary_key}"

          # prepared_statements: true
          #
          #   SELECT `authors`.* FROM `authors` WHERE (`authors`.`id` IN (?, ?, ?) OR `authors`.`id` IS NULL)
          #
          # prepared_statements: false
          #
          #   SELECT `authors`.* FROM `authors` WHERE (`authors`.`id` IN (1, 2, 3) OR `authors`.`id` IS NULL)
          #
          sql = "SELECT #{table}.* FROM #{table} WHERE (#{pk} IN (#{bind_params(1..3)}) OR #{pk} IS NULL)"

          authors = Author.where(id: [1, 2, 3, nil])
          assert_equal sql, @connection.to_sql(authors.arel)
          assert_queries_match(sql) { assert_equal 3, authors.length }

          # prepared_statements: true
          #
          #   SELECT `authors`.* FROM `authors` WHERE `authors`.`id` IN (?, ?, ?)
          #
          # prepared_statements: false
          #
          #   SELECT `authors`.* FROM `authors` WHERE `authors`.`id` IN (1, 2, 3)
          #
          sql = "SELECT #{table}.* FROM #{table} WHERE #{pk} IN (#{bind_params(1..3)})"

          authors = Author.where(id: [1, 2, 3, 9223372036854775808])
          assert_equal sql, @connection.to_sql(authors.arel)
          assert_queries_match(sql) { assert_equal 3, authors.length }

          # prepared_statements: true
          #
          #   SELECT `authors`.* FROM `authors` WHERE `authors`.`id` IN (?, ?, ?)
          #
          # prepared_statements: false
          #
          #   SELECT `authors`.* FROM `authors` WHERE `authors`.`id` IN (1, 2, 3)
          #
          params = if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
            # With MySQL integers are casted as string for security.
            bind_params((1..3).map(&:to_s))
          else
            bind_params(1..3)
          end

          sql = "SELECT #{table}.* FROM #{table} WHERE #{pk} IN (#{params})"
          arel_node = Arel.sql("SELECT #{table}.* FROM #{table} WHERE #{pk} IN (?)", [1, 2, 3])
          assert_equal sql, @connection.to_sql(arel_node)
          assert_queries_match(sql) { assert_equal 3, @connection.select_all(arel_node).length }
        end

        def bind_params(ids)
          collector = @connection.send(:collector)
          bind_params = ids.map { |i| Arel::Nodes::BindParam.new(i) }
          sql, _ = @connection.visitor.compile(bind_params, collector)
          sql
        end

        def to_sql_key(arel)
          sql = @connection.to_sql(arel)
          @connection.respond_to?(:sql_key, true) ? @connection.send(:sql_key, sql) : sql
        end

        def cached_statement(klass, key)
          cache = klass.send(:cached_find_by_statement, @connection, key) do
            raise "#{klass} has no cached statement by #{key.inspect}"
          end
          cache.instance_variable_get(:@query_builder).instance_variable_get(:@sql)
        end

        def statement_cache
          @connection.instance_variable_get(:@statements).send(:cache)
        end

        def assert_logs_binds(binds)
          payload = {
            name: "SQL",
            sql: "select * from topics where id = ?",
            binds: binds,
            type_casted_binds: @connection.send(:type_casted_binds, binds)
          }

          event = ActiveSupport::Notifications::Event.new(
            "foo",
            Time.now,
            Time.now,
            123,
            payload)

          logger = Class.new(ActiveRecord::LogSubscriber) {
            attr_reader :debugs

            def initialize
              super
              @debugs = []
            end

            def debug(str)
              @debugs << str
            end
          }.new

          logger.sql(event)
          assert_match %r(\[\["id", 10\]\]\z), logger.debugs.first
        end

        def assert_logs_unnamed_binds(binds)
          payload = {
            name: "SQL",
            sql: "select * from topics where title = $1",
            binds: binds,
            type_casted_binds: @connection.send(:type_casted_binds, binds)
          }

          event = ActiveSupport::Notifications::Event.new(
            "foo",
            Time.now,
            Time.now,
            123,
            payload)

          logger = Class.new(ActiveRecord::LogSubscriber) {
            attr_reader :debugs

            def initialize
              super
              @debugs = []
            end

            def debug(str)
              @debugs << str
            end
          }.new

          logger.sql(event)
          assert_match %r(\[\[nil, "abcd"\]\]\z), logger.debugs.first
        end

        def assert_filtered_log_binds(binds)
          payload = {
            name: "SQL",
            sql: "select * from users where auth_token = ?",
            binds: binds,
            type_casted_binds: @connection.send(:type_casted_binds, binds)
          }

          event = ActiveSupport::Notifications::Event.new(
            "foo",
            Time.now,
            Time.now,
            123,
            payload)

          logger = Class.new(ActiveRecord::LogSubscriber) {
            attr_reader :debugs

            def initialize
              super
              @debugs = []
            end

            def debug(str)
              @debugs << str
            end
          }.new

          logger.sql(event)
          assert_match %r/#{Regexp.escape '[["auth_token", "[FILTERED]"]]'}/, logger.debugs.first
        end
    end
  end
end
