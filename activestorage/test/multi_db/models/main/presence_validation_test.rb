# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

class ActiveStorage::MainPresenceValidationTest < ActiveSupport::TestCase
  class MainAdmin < MainUser; end

  teardown do
    MainAdmin.clear_validators!
  end

  test "validates_presence_of has_one_attached" do
    MainAdmin.validates_presence_of :avatar
    a = MainAdmin.new(name: "DHH")
    assert_predicate a, :invalid?

    a.avatar.attach create_main_blob(filename: "funky.jpg")
    assert_predicate a, :valid?
  end

  test "validates_presence_of has_many_attached" do
    MainAdmin.validates_presence_of :highlights
    a = MainAdmin.new(name: "DHH")
    assert_predicate a, :invalid?

    a.highlights.attach create_main_blob(filename: "funky.jpg")
    assert_predicate a, :valid?
  end
end
