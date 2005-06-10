require 'abstract_unit'

class TestRecord < ActiveRecord::Base
end

class TestUnconnectedAdaptor < Test::Unit::TestCase
  self.use_transactional_fixtures = false

  def setup
    @connection = ActiveRecord::Base.remove_connection
  end

  def teardown
    ActiveRecord::Base.establish_connection(@connection)
  end

  def test_unconnected
    assert_raise(ActiveRecord::ConnectionNotEstablished) do
      TestRecord.find(1)   
    end
    assert_raise(ActiveRecord::ConnectionNotEstablished) do
      TestRecord.new.save   
    end
  end
end
