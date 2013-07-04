require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class NotificationsTest < ActiveRecord::TestCase
      attr_reader :adapter, :connection

      def setup
        super
        @adapter = AbstractAdapter.new nil, nil
        @connection = ActiveRecord::Base.connection
      end

      def test_sql_notifications
        event = nil
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
          event = args.pop
        end

        sql = "select * from topics"
        connection.exec_query(sql, 'SQL')

        assert_equal event[:sql], sql
        assert_equal event[:name], 'SQL'
        assert_equal event[:connection_id], connection.object_id
        assert_equal event[:configuration], connection.config
        # binds are tested separately in bind_parameter_test.rb

      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end

    end
  end
end
