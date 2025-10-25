# frozen_string_literal: true

require "test_helper"

class ActiveStorage::PresenceValidationTest < ActiveSupport::TestCase
  class Admin < User; end

  teardown do
    Admin.clear_validators!
  end

  test "validates_presence_of has_one_attached" do
    Admin.validates_presence_of :avatar
    a = Admin.new(name: "DHH")
    assert_predicate a, :invalid?

    a.avatar.attach create_blob(filename: "funky.jpg")
    assert_predicate a, :valid?
  end

  test "validates_presence_of has_many_attached" do
    Admin.validates_presence_of :highlights
    a = Admin.new(name: "DHH")
    assert_predicate a, :invalid?

    a.highlights.attach create_blob(filename: "funky.jpg")
    assert_predicate a, :valid?
  end
end
