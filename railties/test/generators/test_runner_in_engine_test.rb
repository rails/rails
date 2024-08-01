# frozen_string_literal: true

require "generators/plugin_test_helper"
require "env_helpers"
require "plugin_helpers"

class TestRunnerInEngineTest < ActiveSupport::TestCase
  include PluginTestHelper
  include EnvHelpers
  include PluginHelpers

  def setup
    @destination_root = Dir.mktmpdir("bukkits")
    generate_plugin("#{@destination_root}/bukkits", "--full")
    plugin_file "test/dummy/db/schema.rb", ""
  end

  def teardown
    FileUtils.rm_rf(@destination_root)
  end

  def test_run_default
    assert_match "0 failures, 0 errors", run_test_command
  end

  def test_rerun_snippet_is_relative_path
    create_test_file "post", pass: false

    output = run_test_command("test/post_test.rb")
    expect = %r{Running:\n\nPostTest\nF\n\nFailure:\nPostTest#test_truth \[.*?test/post_test\.rb:6\]:\nwups!\n\nbin/rails test test/post_test\.rb:4}
    assert_match expect, output
  end

  private
    def plugin_path
      "#{@destination_root}/bukkits"
    end

    def run_test_command(arguments = "")
      Dir.chdir(plugin_path) do
        switch_env("BUNDLE_GEMFILE", "") { `bin/rails test #{arguments}` }
      end
    end
end
