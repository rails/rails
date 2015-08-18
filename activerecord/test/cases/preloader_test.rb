require 'cases/helper'
require 'models/car'

class AssociationsTest < ActiveRecord::TestCase
  fixtures :cars

  def test_preload_with_exception
    exception = assert_raises(ArgumentError) do
      Car.preload(10).to_a
    end
    assert_equal('10 was not recognized for preload', exception.message)
  end
end
