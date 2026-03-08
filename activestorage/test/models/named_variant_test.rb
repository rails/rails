# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "minitest/mock"

class ActiveStorage::NamedVariantTest < ActiveSupport::TestCase
  setup do
    @user = User.new(name: "joe")
  end

  test "explicity sets the process to immediate" do
    named_variant = @user.attachment_reflections["avatar_with_immediate_variants"].named_variants[:immediate_thumb]
    assert_equal :immediately, named_variant.process(@user)
  end

  test "explicity sets the process to later" do
    named_variant = @user.attachment_reflections["avatar_with_later_variants"].named_variants[:later_thumb]
    assert_equal :later, named_variant.process(@user)
  end

  test "explicity sets the process to on_demand" do
    named_variant = @user.attachment_reflections["avatar_with_lazy_variants"].named_variants[:lazy_thumb]
    assert_equal :lazily, named_variant.process(@user)
  end

  test "defaults process to lazy" do
    named_variant = @user.attachment_reflections["avatar_with_lazy_variants"].named_variants[:default_thumb]
    assert_equal :lazily, named_variant.process(@user)
  end

  test "sets the process to later conditionally via preprocessed method" do
    named_variant = @user.attachment_reflections["avatar_with_conditional_preprocessed"].named_variants[:method]
    assert_not_equal :later, named_variant.process(@user)

    @user.name = "transform via method"
    assert_equal :later, named_variant.process(@user)
  end

  test "sets the process to later conditionally via preprocessed proc" do
    named_variant = @user.attachment_reflections["avatar_with_conditional_preprocessed"].named_variants[:proc]
    assert_not_equal :later, named_variant.process(@user)

    @user.update(name: "transform via proc")
    assert_equal :later, named_variant.process(@user)
  end

  test "sets the process to later conditionally via preprocessed boolean" do
    @user = User.create(name: "joe")
    named_variant = @user.attachment_reflections["avatar_with_preprocessed"].named_variants[:bool]
    assert_equal :later, named_variant.process(@user)
  end
end
