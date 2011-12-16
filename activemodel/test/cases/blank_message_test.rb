require 'cases/helper'
require 'models/city'

class BlankMessageTest < ActiveModel::TestCase

  setup do
    @city = City.new
  end

  test "City name" do
    @city.name = ''
    assert !@city.valid?, 'city should not be valid'
  end
end