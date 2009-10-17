require "cases/helper"

class UnknownTest < ActiveRecord::TestCase

  test "typecast attributes does't modify values" do
    unkown = ActiveRecord::Type::Unknown.new
    person = { 'name' => '0' }

    assert_equal person['name'], unkown.cast(person['name'])
    assert_equal person['name'], unkown.precast(person['name'])
  end

  test "cast as boolean" do
    person =  { 'id' => 0, 'name' => ' ', 'admin' => 'false', 'votes' => '0' }
    unkown = ActiveRecord::Type::Unknown.new

    assert_equal false, unkown.boolean(person['votes'])
    assert_equal false, unkown.boolean(person['admin'])
    assert_equal false, unkown.boolean(person['name'])
    assert_equal false, unkown.boolean(person['id'])

    person = { 'id' => 5, 'name' => 'Eric', 'admin' => 'true', 'votes' => '25' }
    assert_equal true, unkown.boolean(person['votes'])
    assert_equal true, unkown.boolean(person['admin'])
    assert_equal true, unkown.boolean(person['name'])
    assert_equal true, unkown.boolean(person['id'])
  end

end