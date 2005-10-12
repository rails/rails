require 'abstract_unit'
require 'fixtures/topic'

class ThreadedConnectionsTest < Test::Unit::TestCase
  self.use_transactional_fixtures = false

  fixtures :topics

  def setup
    @connection = ActiveRecord::Base.remove_connection
    @connections = []
  end
  
  def gather_connections(use_threaded_connections)
    ActiveRecord::Base.allow_concurrency = use_threaded_connections
    ActiveRecord::Base.establish_connection(@connection)
    
    5.times do
      Thread.new do
        Topic.find :first
        @connections << ActiveRecord::Base.active_connections.values.first
      end.join
    end
  end

  def test_threaded_connections
    gather_connections(true)
    assert_equal @connections.uniq.length, 5
  end

  def test_unthreaded_connections
    gather_connections(false)
    assert_equal @connections.uniq.length, 1
  end
end
