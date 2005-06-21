require 'abstract_unit'
require 'fixtures/topic'

class TestColumnAlias < Test::Unit::TestCase

  def test_column_alias
    topic = Topic.find(1)
    if ActiveRecord::ConnectionAdapters.const_defined? :OracleAdapter
      if ActiveRecord::Base.connection.instance_of?(ActiveRecord::ConnectionAdapters::OracleAdapter)
        records = topic.connection.select_all("SELECT id AS pk FROM topics WHERE ROWNUM < 2")
        assert_equal("pk", records[0].keys[0])
      end
    else
      records = topic.connection.select_all("SELECT id AS pk FROM topics")
      assert_equal("pk", records[0].keys[0])
    end
  end
  
end
