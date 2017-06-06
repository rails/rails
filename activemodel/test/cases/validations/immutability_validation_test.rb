require 'cases/helper'
require 'models/topic'

class ImmutbilityValidationTest < ActiveModel::TestCase
  def test_validates_immutability_of
    Topic.validates_immutability_of(:title)

    t = Topic.new(title: 'A title')
    t.title = 'Another title'

    assert t.invalid?
    assert_equal ['can\'t be changed'], t.errors[:title]
  end
end
