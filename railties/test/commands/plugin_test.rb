# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"
require "rails/generators/rails/plugin/plugin_generator"

class Rails::Command::PluginTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  def test_plugin_with_invalid_subcommand
    output = run_plugin_command("foo", "bar", allow_failure: true)

    assert_equal 1, $?.exitstatus
    assert_match "'foo' is not a valid plugin subcommand. Valid subcommand: new.", output
  end

  def test_plugin_new_without_path_shows_help
    output = run_plugin_command("new", allow_failure: true)

    assert_match "rails plugin new APP_PATH", output
  end

  def test_plugin_help
    output = run_plugin_command("--help", allow_failure: true)

    assert_match "rails plugin new", output
  end

  def test_plugin_new_with_mountable_option
    assert_plugin_generator_called_with("my_plugin", "--mountable", "--pretend") do
      invoke_plugin_command("new", "my_plugin", "--mountable", "--pretend")
    end
  end

  def test_plugin_new_with_full_option
    assert_plugin_generator_called_with("my_plugin", "--full", "--pretend") do
      invoke_plugin_command("new", "my_plugin", "--full", "--pretend")
    end
  end

  def test_plugin_new_with_skip_test_option
    assert_plugin_generator_called_with("my_plugin", "--skip-test", "--pretend") do
      invoke_plugin_command("new", "my_plugin", "--skip-test", "--pretend")
    end
  end

  private
    def assert_plugin_generator_called_with(*arguments, &block)
      assert_called_with(Rails::Generators::PluginGenerator, :start, [arguments], &block)
    end

    def invoke_plugin_command(*arguments)
      Rails::Command.invoke(:plugin, arguments)
    end

    def run_plugin_command(*arguments, allow_failure: false)
      rails "plugin", *arguments, allow_failure: allow_failure
    end
end
