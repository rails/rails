require 'generators/generators_test_helper'
require 'rails/generators/rails/plugin/plugin_generator'

class PluginGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(plugin_fu)

  def test_plugin_skeleton_is_created
    silence(:stderr) { run_generator }
    year = Date.today.year

    %w(
      vendor/plugins
      vendor/plugins/plugin_fu
      vendor/plugins/plugin_fu/init.rb
      vendor/plugins/plugin_fu/install.rb
      vendor/plugins/plugin_fu/uninstall.rb
      vendor/plugins/plugin_fu/lib
      vendor/plugins/plugin_fu/lib/plugin_fu.rb
      vendor/plugins/plugin_fu/Rakefile
    ).each{ |path| assert_file path }

    %w(
      vendor/plugins/plugin_fu/README
    ).each{ |path| assert_file path, /PluginFu/ }

    %w(
      vendor/plugins/plugin_fu/README
      vendor/plugins/plugin_fu/MIT-LICENSE
    ).each{ |path| assert_file path, /#{year}/ }
  end

  def test_check_class_collision
    content = capture(:stderr){ run_generator ["object"] }
    assert_match(/The name 'Object' is either already used in your application or reserved/, content)
  end

  def test_invokes_default_test_framework
    silence(:stderr) { run_generator }
    assert_file "vendor/plugins/plugin_fu/test/plugin_fu_test.rb", /class PluginFuTest < ActiveSupport::TestCase/
    assert_file "vendor/plugins/plugin_fu/test/test_helper.rb"
  end

  def test_logs_if_the_test_framework_cannot_be_found
    content = nil
    silence(:stderr) { content = run_generator ["plugin_fu", "--test-framework=rspec"] }
    assert_match(/rspec \[not found\]/, content)
  end

  def test_creates_tasks_if_required
    silence(:stderr) { run_generator ["plugin_fu", "--tasks"] }
    assert_file "vendor/plugins/plugin_fu/lib/tasks/plugin_fu_tasks.rake"
  end

  def test_creates_generator_if_required
    silence(:stderr) { run_generator ["plugin_fu", "--generator"] }
    assert_file "vendor/plugins/plugin_fu/lib/generators/templates"
    assert_file "vendor/plugins/plugin_fu/lib/generators/plugin_fu_generator.rb",
                /class PluginFuGenerator < Rails::Generators::NamedBase/
  end

  def test_plugin_generator_on_revoke
    silence(:stderr) { run_generator }
    run_generator ["plugin_fu"], :behavior => :revoke
  end

  def test_deprecation
    output = capture(:stderr) { run_generator }
    assert_match(/Plugin generator is deprecated, please use 'rails plugin new' command to generate plugin structure./, output)
  end
end
