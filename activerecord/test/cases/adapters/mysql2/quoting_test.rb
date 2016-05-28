require "cases/helper"

class Mysql2QuotingTest < ActiveRecord::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
  end

  test 'quoted date precision for gte 5.6.4' do
    @connection.stubs(:full_version).returns('5.6.4')
    @connection.send(:remove_instance_variable, :@version) if @connection.instance_variable_defined?(:@version)
    t = Time.now.change(usec: 1)
    assert_match(/\.000001\z/, @connection.quoted_date(t))
  end

  test 'quoted date precision for lt 5.6.4' do
    @connection.stubs(:full_version).returns('5.6.3')
    @connection.send(:remove_instance_variable, :@version) if @connection.instance_variable_defined?(:@version)
    t = Time.now.change(usec: 1)
    refute_match(/\.000001\z/, @connection.quoted_date(t))
  end
end
