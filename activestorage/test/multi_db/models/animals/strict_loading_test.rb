# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

class ActiveStorage::AnimalsStrictLoadingTest < ActiveSupport::TestCase
  class AnimalsAdmin < AnimalsUser
    has_one_attached :image, strict_loading: true
    has_many_attached :images, strict_loading: true
  end

  setup do
    AnimalsAdmin.create!(name: "David")
  end

  test "has_one_attached raises if strict loading and lazy loading" do
    assert_raises ActiveRecord::StrictLoadingViolationError do
      admins = AnimalsAdmin.all
      admins.as_json(include: :image)
    end
  end

  test "has_many_attached raises if strict loading and lazy loading" do
    assert_raises ActiveRecord::StrictLoadingViolationError do
      admins = AnimalsAdmin.all
      admins.as_json(include: :images)
    end
  end
end
