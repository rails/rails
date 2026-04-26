require "cases/helper"

class BaseAttributeTest < ActiveRecord::TestCase
  def test_attribute_can_be_defined_without_db_connection
    klass = Class.new(ActiveRecord::Base) do
      self.abstract_class = "true"
      attribute :foo, :string
    end

    obj = klass.new
    obj.foo = "bar"
    assert_equal "bar", obj.foo
  end
end