# frozen_string_literal: true

require "test_helper"

class ActiveStorage::ReflectionTest < ActiveSupport::TestCase
  test "allows reflecting for all attachment" do
    expected_classes =
      User.reflect_on_all_attachments.all? do |reflection|
        reflection.is_a?(ActiveRecord::Reflection::HasOneAttachedReflection) ||
          reflection.is_a?(ActiveRecord::Reflection::HasManyAttachedReflection)
      end

    assert expected_classes
  end

  test "allows reflecting on a singular has_one_attached attachment" do
    reflection = User.reflect_on_attachment(:avatar)

    assert_equal :avatar, reflection.name
    assert_equal :has_one_attached, reflection.macro
  end

  test "allows reflecting on a singular has_many_attached attachment" do
    reflection = User.reflect_on_attachment(:highlights)

    assert_equal :highlights, reflection.name
    assert_equal :has_many_attached, reflection.macro
  end
end
