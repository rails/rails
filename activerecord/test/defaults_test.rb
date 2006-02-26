require 'abstract_unit'
require 'fixtures/default'

if %w(PostgreSQL).include? ActiveRecord::Base.connection.adapter_name
  class DefaultsTest < Test::Unit::TestCase
    def test_default_integers
      default = Default.new
      assert_instance_of(Fixnum, default.positive_integer)
      assert_equal(default.positive_integer, 1)
      assert_instance_of(Fixnum, default.negative_integer)
      assert_equal(default.negative_integer, -1)
    end
  end
end
