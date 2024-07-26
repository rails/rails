require 'abstract_unit'

class TestRecord < ActiveRecord::Base
end

class TestUnconnectedAdaptor < Test::Unit::TestCase
  def setup
    @config = Marshal::dump(ActiveRecord::Base.class_eval("@@config"))
    ActiveRecord::Base.class_eval "@@config = Thread.current['connection'] = nil"
  end
  
  def teardown
    ActiveRecord::Base.class_eval "@@config = Marshal::load('#{@config}')"
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
