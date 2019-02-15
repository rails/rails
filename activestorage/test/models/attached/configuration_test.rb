# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AttachedConfigurationTest < ActiveSupport::TestCase
  test "defining a variant" do
    config = ActiveStorage::Attached::Configuration.new

    config.has_variant(:foo, resize: "20x20")
    assert_equal({ resize: "20x20" }, config[:defined_variants][:foo])
  end

  test "variant names are always stored as symbols" do
    config = ActiveStorage::Attached::Configuration.new

    config.has_variant("foo", resize: "20x20")

    assert_equal({ resize: "20x20" }, config[:defined_variants][:foo])
    assert_nil config[:defined_variants]["foo"]
  end

  test "accessing a variant name that is not defined" do
    config = ActiveStorage::Attached::Configuration.new
    assert_nil config[:defined_variants][:some_undefined_variant]
  end
end
