require "cases/helper"

class AliasingTest < ActiveRecord::TestCase

  class AliasingAttributes < Hash
    include ActiveRecord::Attributes::Aliasing
  end

  test "attribute access with aliasing" do
    attributes = AliasingAttributes.new
    attributes[:name] = 'Batman'
    attributes.aliases['nickname'] = 'name'

    assert_equal 'Batman', attributes[:name], "Symbols should point to Strings"
    assert_equal 'Batman', attributes['name']
    assert_equal 'Batman', attributes['nickname']
    assert_equal 'Batman', attributes[:nickname]
  end

end
