require 'cases/helper'
require 'models/contact'

class ConversionTest < ActiveModel::TestCase
  test "to_model default implementation returns self" do
    contact = Contact.new
    assert_equal contact, contact.to_model
  end

  test "to_key default implementation returns nil for new records" do
    assert_nil Contact.new.to_key
  end

  test "to_key default implementation returns the id in an array for persisted records" do
    assert_equal [1], Contact.new(:id => 1).to_key
  end

  test "to_param default implementation returns nil for new records" do
    assert_nil Contact.new.to_param
  end

  test "to_param default implementation returns a string of ids for persisted records" do
    assert_equal "1", Contact.new(:id => 1).to_param
  end
end