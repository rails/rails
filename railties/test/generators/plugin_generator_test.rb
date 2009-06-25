require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/plugin/plugin_generator'
require 'generators/test_unit/plugin/plugin_generator'

class PluginGeneratorTest < GeneratorsTestCase

  def test_plugin_skeleton_is_created
    run_generator

    %w(
      vendor/plugins
      vendor/plugins/plugin_fu
      vendor/plugins/plugin_fu/lib
    ).each{ |path| assert_file path }
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "vendor/plugins/plugin_fu/test/plugin_fu_test.rb"
  end

  def test_logs_if_the_test_framework_cannot_be_found
    content = run_generator ["--test-framework=unknown"]
    assert_match /Could not find and invoke 'unknown:generators:plugin'/, content
  end

  def test_creates_tasks_if_required
    run_generator ["--with-tasks"]
    assert_file "vendor/plugins/plugin_fu/tasks/plugin_fu_tasks.rake"
  end

  def test_creates_generator_if_required
    run_generator ["--with-generator"]
    assert_file "vendor/plugins/plugin_fu/generators/plugin_fu/templates"

    flag = /class PluginFuGenerator < Rails::Generators::NamedBase/
    assert_file "vendor/plugins/plugin_fu/generators/plugin_fu/plugin_fu_generator.rb", flag
  end

  protected

    def run_generator(args=[])
      silence(:stdout) { Rails::Generators::PluginGenerator.start ["plugin_fu"].concat(args), :root => destination_root }
    end

end
