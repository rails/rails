require 'cases/helper'
require 'models/topic'

class ImmutbilityValidationTest < ActiveRecord::TestCase
  def test_validates_immutability_of_for_persisted_record
    Topic.validates_immutability_of(:title)

    t = Topic.create(title: 'A title')
    t.title = 'Another title'

    assert t.invalid?
    assert_equal ['can\'t be changed'], t.errors[:title]
  end

  def test_validates_immutability_of_for_new_record
    t = Topic.new(title: 'A title')
    t.title = 'Another title'

    assert t.valid?
    assert_empty t.errors[:title]
  end
end
