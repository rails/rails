require 'abstract_unit'

class ConnectionTest < Test::Unit::TestCase
  def test_charset_properly_set
    fb_conn = ActiveRecord::Base.connection.instance_variable_get(:@connection)
    assert_equal 'UTF8', fb_conn.database.character_set
  end
end
