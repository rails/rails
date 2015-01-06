require 'cases/helper'
require 'models/topic'
require 'models/author'
require 'models/post'

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
      @subscriber   = LogListener.new
      @pk         = Topic.columns_hash[Topic.primary_key]
      @subscription = ActiveSupport::Notifications.subscribe('sql.active_record', @subscriber)
    end

    teardown do
      ActiveSupport::Notifications.unsubscribe(@subscription)
    end

    if ActiveRecord::Base.connection.supports_statement_cache?
      def test_bind_from_join_in_subquery
        subquery = Author.joins(:thinking_posts).where(name: 'David')
        scope = Author.from(subquery, 'authors').where(id: 1)
        assert_equal 1, scope.count
      end

      def test_binds_are_logged
        sub   = @connection.substitute_at(@pk)
        binds = [[@pk, 1]]
        sql   = "select * from topics where id = #{sub.to_sql}"

        @connection.exec_query(sql, 'SQL', binds)

        message = @subscriber.calls.find { |args| args[4][:sql] == sql }
        assert_equal binds, message[4][:binds]
      end

      def test_binds_are_logged_after_type_cast
        sub   = @connection.substitute_at(@pk)
        binds = [[@pk, "3"]]
        sql   = "select * from topics where id = #{sub.to_sql}"

        @connection.exec_query(sql, 'SQL', binds)

        message = @subscriber.calls.find { |args| args[4][:sql] == sql }
        assert_equal [[@pk, 3]], message[4][:binds]
      end

      def test_find_one_uses_binds
        Topic.find(1)
        binds = [[@pk, 1]]
        message = @subscriber.calls.find { |args| args[4][:binds] == binds }
        assert message, 'expected a message with binds'
      end

      def test_logs_bind_vars
        payload = {
          :name  => 'SQL',
          :sql   => 'select * from topics where id = ?',
          :binds => [[@pk, 10]]
        }
        event  = ActiveSupport::Notifications::Event.new(
          'foo',
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
    end
  end
end
