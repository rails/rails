require "cases/helper"

class MysqlQuotingTest < ActiveRecord::MysqlTestCase
  def setup
    @conn = ActiveRecord::Base.connection
  end

  def test_type_cast_true
    assert_equal 1, @conn.type_cast(true)
  end

  def test_type_cast_false
    assert_equal 0, @conn.type_cast(false)
  end

  def test_quoted_date_precision_for_gte_564
    @conn.stubs(:full_version).returns('5.6.4')
    @conn.remove_instance_variable(:@version) if @conn.instance_variable_defined?(:@version)
    t = Time.now.change(usec: 1)
    assert_match(/\.000001\z/, @conn.quoted_date(t))
  end

  def test_quoted_date_precision_for_lt_564
    @conn.stubs(:full_version).returns('5.6.3')
    @conn.remove_instance_variable(:@version) if @conn.instance_variable_defined?(:@version)
    t = Time.now.change(usec: 1)
    assert_no_match(/\.000001\z/, @conn.quoted_date(t))
  end
end
