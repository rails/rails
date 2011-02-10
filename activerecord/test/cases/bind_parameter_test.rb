require 'cases/helper'
require 'models/topic'

module ActiveRecord
  class BindParameterTest < ActiveRecord::TestCase
    class LogListener
      attr_accessor :calls

      def initialize
        @calls = []
      end

      def call(*args)
        calls << args
      end
    end

    fixtures :topics

    def setup
      super
      @connection = ActiveRecord::Base.connection
      @listener   = LogListener.new
      @pk         = Topic.columns.find { |c| c.primary }
      ActiveSupport::Notifications.subscribe('sql.active_record', @listener)
    end

    def teardown
      ActiveSupport::Notifications.unsubscribe(@listener)
    end

    def test_binds_are_logged
      # FIXME: use skip with minitest
      return unless @connection.supports_statement_cache?

      sub   = @connection.substitute_for(@pk, [])
      binds = [[@pk, 1]]
      sql   = "select * from topics where id = #{sub}"

      @connection.exec_query(sql, 'SQL', binds)

      message = @listener.calls.find { |args| args[4][:sql] == sql }
      assert_equal binds, message[4][:binds]
    end

    def test_find_one_uses_binds
      # FIXME: use skip with minitest
      return unless @connection.supports_statement_cache?

      Topic.find(1)
      binds = [[@pk, 1]]
      message = @listener.calls.find { |args| args[4][:binds] == binds }
      assert message, 'expected a message with binds'
    end
  end
end
