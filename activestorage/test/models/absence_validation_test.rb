# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AbsenceValidationTest < ActiveSupport::TestCase
  class Admin < User; end

  teardown do
    Admin.clear_validators!
  end

  test "validates_absence_of has_one_attached" do
    Admin.validates_absence_of :avatar
    a = Admin.new
    assert_predicate a, :valid?

    a.avatar.attach create_blob(filename: "funky.jpg")
    assert_predicate a, :invalid?
  end

  test "validates_absende_of has_many_attached" do
    Admin.validates_absence_of :highlights
    a = Admin.new
    assert_predicate a, :valid?

    a.highlights.attach create_blob(filename: "funky.jpg")
    assert_predicate a, :invalid?
  end
end
