require 'cases/helper'
require 'models/contact'

class PresenceTest < ActiveModel::TestCase
  test 'Model#present?' do
    contact = Contact.new
    assert_equal true, contact.present?
  end

  test 'Model#blank?' do
    contact = Contact.new
    assert_equal false, contact.blank?
  end
end
