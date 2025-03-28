# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

class ActiveStorage::AnimalsPresenceValidationTest < ActiveSupport::TestCase
  class AnimalsAdmin < AnimalsUser; end

  teardown do
    AnimalsAdmin.clear_validators!
  end

  test "validates_presence_of has_one_attached" do
    AnimalsAdmin.validates_presence_of :avatar
    a = AnimalsAdmin.new(name: "DHH")
    assert_predicate a, :invalid?

    a.avatar.attach create_animals_blob(filename: "funky.jpg")
    assert_predicate a, :valid?
  end

  test "validates_presence_of has_many_attached" do
    AnimalsAdmin.validates_presence_of :highlights
    a = AnimalsAdmin.new(name: "DHH")
    assert_predicate a, :invalid?

    a.highlights.attach create_animals_blob(filename: "funky.jpg")
    assert_predicate a, :valid?
  end
end
