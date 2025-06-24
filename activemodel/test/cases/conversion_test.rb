# frozen_string_literal: true

require "cases/helper"
require "models/contact"
require "models/helicopter"

class ConversionTest < ActiveModel::TestCase
  test "to_model default implementation returns self" do
    contact = Contact.new
    assert_equal contact, contact.to_model
  end

  test "to_key default implementation returns nil for new records" do
    assert_nil Contact.new.to_key
  end

  test "to_key default implementation returns the id in an array for persisted records" do
    assert_equal [1], Contact.new(id: 1).to_key
  end

  test "to_key doesn't double-wrap composite `id`s" do
    assert_equal ["abc", "xyz"], Contact.new(id: ["abc", "xyz"]).to_key
  end

  test "to_param default implementation returns nil for new records" do
    assert_nil Contact.new.to_param
  end

  test "to_param default implementation returns a string of ids for persisted records" do
    assert_equal "1", Contact.new(id: 1).to_param
  end

  test "to_param returns the string joined by '-'" do
    assert_equal "abc-xyz", Contact.new(id: ["abc", "xyz"]).to_param
  end

  test "to_param returns nil if composite id is incomplete" do
    assert_nil Contact.new(id: [1, nil]).to_param
  end

  test "to_param returns nil if to_key is nil" do
    klass = Class.new(Contact) do
      def persisted?
        true
      end
    end

    assert_nil klass.new.to_param
  end

  test "to_partial_path default implementation returns a string giving a relative path" do
    assert_equal "contacts/contact", Contact.new.to_partial_path
    assert_equal "helicopters/helicopter", Helicopter.new.to_partial_path,
      "ActiveModel::Conversion#to_partial_path caching should be class-specific"
  end

  test "to_partial_path handles namespaced models" do
    assert_equal "helicopter/comanches/comanche", Helicopter::Comanche.new.to_partial_path
  end

  test "to_partial_path handles non-standard model_name" do
    assert_equal "attack_helicopters/ah-64", Helicopter::Apache.new.to_partial_path
  end

  test "#to_param_delimiter allows redefining the delimiter used in #to_param" do
    old_delimiter = Contact.param_delimiter
    Contact.param_delimiter = "_"
    assert_equal("abc_xyz", Contact.new(id: ["abc", "xyz"]).to_param)
  ensure
    Contact.param_delimiter = old_delimiter
  end

  test "#to_param_delimiter is defined per class" do
    old_contact_delimiter = Contact.param_delimiter
    custom_contract = Class.new(Contact)

    Contact.param_delimiter = "_"
    custom_contract.param_delimiter = ";"

    assert_equal("abc_xyz", Contact.new(id: ["abc", "xyz"]).to_param)
    assert_equal("abc;xyz", custom_contract.new(id: ["abc", "xyz"]).to_param)
  ensure
    Contact.param_delimiter = old_contact_delimiter
  end
end
