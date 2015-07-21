require "cases/helper"

class Mysql2QuotingTest < ActiveRecord::Mysql2TestCase
  setup do
    @connection = ActiveRecord::Base.connection
  end

  test 'quoted date precision for gte 5.6.4' do
    @connection.stubs(:full_version).returns('5.6.4')
    @connection.remove_instance_variable(:@version)
    t = Time.now.change(usec: 1)
    assert_match(/\.000001\z/, @connection.quoted_date(t))
  end

  test 'quoted date precision for lt 5.6.4' do
    @connection.stubs(:full_version).returns('5.6.3')
    @connection.remove_instance_variable(:@version)
    t = Time.now.change(usec: 1)
    refute_match(/\.000001\z/, @connection.quoted_date(t))
  end
end
