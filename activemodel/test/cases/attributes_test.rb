require 'cases/helper'

class AttributesTest < ActiveModel::TestCase
  class Person
    include ActiveModel::Attributes
    attr_accessor :name
  end

  test "reads attribute" do
    p = Person.new
    assert_equal nil, p.read_attribute(:name)

    p.name = "Josh"
    assert_equal "Josh", p.read_attribute(:name)
  end

  test "writes attribute" do
    p = Person.new
    assert_equal nil, p.name

    p.write_attribute(:name, "Josh")
    assert_equal "Josh", p.name
  end

  test "returns all attributes" do
    p = Person.new
    p.name = "Josh"
    assert_equal({"name" => "Josh"}, p.attributes)
  end
end
