require "cases/helper"
require 'models/topic'
require 'models/reply'

unless %w(FrontBase).include? ActiveRecord::Base.connection.adapter_name
  class ThreadedConnectionsTest < ActiveRecord::TestCase
    self.use_transactional_fixtures = false

    fixtures :topics

    def setup
      @connection = ActiveRecord::Base.remove_connection
      @connections = []
    end

    def teardown
      # clear the connection cache
      ActiveRecord::Base.clear_active_connections!
      # reestablish old connection
      ActiveRecord::Base.establish_connection(@connection)
    end

    def gather_connections
      ActiveRecord::Base.establish_connection(@connection)

      5.times do
        Thread.new do
          Topic.find :first
          @connections << ActiveRecord::Base.active_connections.first
        end.join
      end
    end

    def test_threaded_connections
      gather_connections
      assert_equal @connections.length, 5
    end
  end
end
