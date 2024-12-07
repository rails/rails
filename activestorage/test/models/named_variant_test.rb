# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "minitest/mock"

class ActiveStorage::NamedVariantTest < ActiveSupport::TestCase
  setup do
    @user = User.new(name: "joe")
  end

  test "explicity sets the generation to immediate" do
    named_variant = @user.attachment_reflections["avatar_with_immediate_variants"].named_variants[:immediate_thumb]
    assert_equal :immediate, named_variant.generation(@user)
  end

  test "explicity sets the generation to delayed" do
    named_variant = @user.attachment_reflections["avatar_with_delayed_variants"].named_variants[:delayed_thumb]
    assert_equal :delayed, named_variant.generation(@user)
  end

  test "explicity sets the generation to on_demand" do
    named_variant = @user.attachment_reflections["avatar_with_on_demand_variants"].named_variants[:on_demand_thumb]
    assert_equal :on_demand, named_variant.generation(@user)
  end

  test "defaults generation to on_demand" do
    named_variant = @user.attachment_reflections["avatar_with_on_demand_variants"].named_variants[:default_thumb]
    assert_equal :on_demand, named_variant.generation(@user)
  end

  test "sets the generation to delayed conditionally via preprocessed method" do
    named_variant = @user.attachment_reflections["avatar_with_conditional_preprocessed"].named_variants[:method]
    assert_not_equal :delayed, named_variant.generation(@user)

    @user.name = "transform via method"
    assert_equal :delayed, named_variant.generation(@user)
  end

  test "sets the generation to delayed conditionally via preprocessed proc" do
    named_variant = @user.attachment_reflections["avatar_with_conditional_preprocessed"].named_variants[:proc]
    assert_not_equal :delayed, named_variant.generation(@user)

    @user.update(name: "transform via proc")
    assert_equal :delayed, named_variant.generation(@user)
  end

  test "sets the generation to delayed conditionally via preprocessed boolean" do
    @user = User.create(name: "joe")
    named_variant = @user.attachment_reflections["avatar_with_preprocessed"].named_variants[:bool]
    assert_equal :delayed, named_variant.generation(@user)
  end
end
