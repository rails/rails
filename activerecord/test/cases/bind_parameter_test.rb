require "cases/helper"
require "models/topic"
require "models/author"
require "models/post"

module ActiveRecord
  class BindParameterTest < ActiveRecord::TestCase
    fixtures :topics, :authors, :posts

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
      @connection = ActiveRecord::Base.connection
      @subscriber = LogListener.new
      @pk = Topic.columns_hash[Topic.primary_key]
      @subscription = ActiveSupport::Notifications.subscribe("sql.active_record", @subscriber)
    end

    teardown do
      ActiveSupport::Notifications.unsubscribe(@subscription)
    end

    if ActiveRecord::Base.connection.supports_statement_cache? &&
       ActiveRecord::Base.connection.prepared_statements
      def test_bind_from_join_in_subquery
        subquery = Author.joins(:thinking_posts).where(name: "David")
        scope = Author.from(subquery, "authors").where(id: 1)
        assert_equal 1, scope.count
      end

      def test_binds_are_logged
        sub   = Arel::Nodes::BindParam.new
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

      def test_logs_bind_vars_after_type_cast
        binds = [Relation::QueryAttribute.new("id", "10", Type::Integer.new)]
        type_casted_binds = binds.map { |attr| type_cast(attr.value_for_database) }
        payload = {
          :name  => "SQL",
          :sql   => "select * from topics where id = ?",
          :binds => binds,
          :type_casted_binds => type_casted_binds
        }
        event  = ActiveSupport::Notifications::Event.new(
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

          def debug str
            @debugs << str
          end
        }.new

        logger.sql event
        assert_match([[@pk.name, 10]].inspect, logger.debugs.first)
      end

      private

      def type_cast(value)
        ActiveRecord::Base.connection.type_cast(value)
      end
    end
  end
end
