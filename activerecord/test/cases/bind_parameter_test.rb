require 'cases/helper'
require 'models/topic'

module ActiveRecord
  class BindParameterTest < ActiveRecord::TestCase
    fixtures :topics

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
      @listener   = LogListener.new
      @pk         = Topic.columns.find { |c| c.primary }
      ActiveSupport::Notifications.subscribe('sql.active_record', @listener)

      skip_if_prepared_statement_caching_is_not_supported
    end

    def teardown
      ActiveSupport::Notifications.unsubscribe(@listener)
    end

    def test_binds_are_logged
      sub   = @connection.substitute_at(@pk, 0)
      binds = [[@pk, 1]]
      sql   = "select * from topics where id = #{sub}"

      @connection.exec_query(sql, 'SQL', binds)

      message = @listener.calls.find { |args| args[4][:sql] == sql }
      assert_equal binds, message[4][:binds]
    end

    def test_find_one_uses_binds
      Topic.find(1)
      binds = [[@pk, 1]]
      message = @listener.calls.find { |args| args[4][:binds] == binds }
      assert message, 'expected a message with binds'
    end

    def test_logs_bind_vars
      pk = Topic.columns.find { |x| x.primary }

      payload = {
        :name  => 'SQL',
        :sql   => 'select * from topics where id = ?',
        :binds => [[pk, 10]]
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
        assert_match([[pk.name, 10]].inspect, logger.debugs.first)
    end

    private

    def skip_if_prepared_statement_caching_is_not_supported
      skip('prepared statement caching is not supported') unless @connection.supports_statement_cache?
    end
  end
end
