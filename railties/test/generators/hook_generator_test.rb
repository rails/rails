# frozen_string_literal: true

require "generators/generators_test_helper"

class HookGeneratorTest < ActiveSupport::TestCase
  class GeneratorWithHook < Rails::Generators::Base
    hook_for(:test_framework)
  end

  class GeneratorWithoutHook < GeneratorWithHook
    remove_hook_for(:test_framework)
  end

  def test_hook_added
    assert GeneratorWithHook.respond_to?(:test_framework_generator)
    assert GeneratorWithHook.hooks.key?(:test_framework)
  end

  def test_hook_removed
    assert_not GeneratorWithoutHook.respond_to?(:test_framework_generator)
    assert_not GeneratorWithoutHook.hooks.key?(:test_framework)
  end
end
