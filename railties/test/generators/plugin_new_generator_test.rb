require 'abstract_unit'
require 'generators/generators_test_helper'
require 'rails/generators/rails/plugin_new/plugin_new_generator'

DEFAULT_PLUGIN_FILES = %w(
  .gitignore
  Gemfile
  Rakefile
  bukkits.gemspec
  MIT-LICENSE
  lib
  lib/bukkits.rb
  script/rails
  test/bukkits_test.rb
  test/integration/navigation_test.rb
  test/support/integration_case.rb
  test/test_helper.rb
  test/dummy
)


class PluginNewGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  destination File.join(Rails.root, "tmp/bukkits")
  arguments [destination_root]

  def setup
    Rails.application = TestApp::Application
    super
    @bundle_command = File.basename(Thor::Util.ruby_command).sub(/ruby/, 'bundle')

    Kernel::silence_warnings do
      Thor::Base.shell.send(:attr_accessor, :always_force)
      @shell = Thor::Base.shell.new
      @shell.send(:always_force=, true)
    end
  end

  def teardown
    super
    Rails.application = TestApp::Application.instance
  end

  def test_plugin_skeleton_is_created
    run_generator

    DEFAULT_PLUGIN_FILES.each{ |path| assert_file path }
  end

  def test_plugin_new_generate_pretend
    run_generator ["testapp", "--pretend"]

    DEFAULT_PLUGIN_FILES.each{ |path| assert_no_file path }
  end

  def test_options_before_plugin_name_raises_an_error
    content = capture(:stderr){ run_generator(["--pretend", destination_root]) }
    assert_equal "Options should be given after plugin name. For details run: rails plugin --help\n", content
  end

  def test_name_collision_raises_an_error
    reserved_words = %w[application destroy plugin runner test]
    reserved_words.each do |reserved|
      content = capture(:stderr){ run_generator [File.join(destination_root, reserved)] }
      assert_equal "Invalid plugin name #{reserved}. Please give a name which does not match one of the reserved rails words.\n", content
    end
  end

  def test_invalid_plugin_name_raises_an_error
    content = capture(:stderr){ run_generator [File.join(destination_root, "43-things")] }
    assert_equal "Invalid plugin name 43-things. Please give a name which does not start with numbers.\n", content
  end

  def test_plugin_name_raises_an_error_if_name_already_used_constant
    %w{ String Hash Class Module Set Symbol }.each do |ruby_class|
      content = capture(:stderr){ run_generator [File.join(destination_root, ruby_class)] }
      assert_equal "Invalid plugin name #{ruby_class}, constant #{ruby_class} is already in use. Please choose another application name.\n", content
    end
  end

  def test_invalid_plugin_name_is_fixed
    run_generator [File.join(destination_root, "things-43")]
    assert_file "things-43/lib/things-43.rb", /module Things43/
  end

  def test_shebang_is_added_to_rails_file
    run_generator [destination_root, "--ruby", "foo/bar/baz"]
    assert_file "script/rails", /#!foo\/bar\/baz/
  end

  def test_shebang_when_is_the_same_as_default_use_env
    run_generator [destination_root, "--ruby", Thor::Util.ruby_command]
    assert_file "script/rails", /#!\/usr\/bin\/env/
  end

  def test_generating_test_files
    run_generator
    assert_file "test/test_helper.rb"
    assert_directory "test/support/"
    assert_directory "test/integration/"

    assert_file "test/bukkits_test.rb", /assert_kind_of Module, Bukkits/
    assert_file "test/integration/navigation_test.rb", /assert_kind_of Dummy::Application, Rails.application/
    assert_file "test/support/integration_case.rb", /class ActiveSupport::IntegrationCase/
  end

  def test_ensure_that_plugin_options_are_not_passed_app_generator
    output = run_generator [destination_root, "--skip_gemfile"]
    assert_no_file "Gemfile"
    assert_match /STEP 2.*create  Gemfile/m, output
  end

  def test_template_from_dir_pwd
    FileUtils.cd(Rails.root)
    assert_match /It works from file!/, run_generator([destination_root, "-m", "lib/template.rb"])
  end

  def test_template_raises_an_error_with_invalid_path
    content = capture(:stderr){ run_generator([destination_root, "-m", "non/existant/path"]) }
    assert_match /The template \[.*\] could not be loaded/, content
    assert_match /non\/existant\/path/, content
  end

  def test_template_is_executed_when_supplied
    path = "http://gist.github.com/103208.txt"
    template = %{ say "It works!" }
    template.instance_eval "def read; self; end" # Make the string respond to read

    generator([destination_root], :template => path).expects(:open).with(path, 'Accept' => 'application/x-thor-template').returns(template)
    assert_match /It works!/, silence(:stdout){ generator.invoke_all }
  end

  def test_dev_option
    generator([destination_root], :dev => true).expects(:run).with("#{@bundle_command} install")
    silence(:stdout){ generator.invoke_all }
    rails_path = File.expand_path('../../..', Rails.root)
    assert_file 'Gemfile', /^gem\s+["']rails["'],\s+:path\s+=>\s+["']#{Regexp.escape(rails_path)}["']$/
  end

  def test_edge_option
    generator([destination_root], :edge => true).expects(:run).with("#{@bundle_command} install")
    silence(:stdout){ generator.invoke_all }
    assert_file 'Gemfile', %r{^gem\s+["']rails["'],\s+:git\s+=>\s+["']#{Regexp.escape("git://github.com/rails/rails.git")}["']$}
  end

  def test_ensure_that_tests_works
    run_generator
    FileUtils.cd destination_root
    `bundle install`
    assert_match /2 tests, 2 assertions, 0 failures, 0 errors/, `bundle exec rake test`
  end

protected

  def action(*args, &block)
    silence(:stdout){ generator.send(*args, &block) }
  end

end

class CustomPluginGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  tests Rails::Generators::PluginNewGenerator

  destination File.join(Rails.root, "tmp/bukkits")
  arguments [destination_root]

  def setup
    Rails.application = TestApp::Application
    super
    @bundle_command = File.basename(Thor::Util.ruby_command).sub(/ruby/, 'bundle')
  end

  def teardown
    super
    Object.class_eval { remove_const :PluginBuilder if const_defined?(:PluginBuilder) }
    Rails.application = TestApp::Application.instance
  end

  def test_builder_option_with_empty_app_builder
    FileUtils.cd(destination_root)
    run_generator([destination_root, "-b", "#{Rails.root}/lib/plugin_builders/empty_builder.rb"])
    DEFAULT_PLUGIN_FILES.each{ |path| assert_no_file path }
  end

  def test_builder_option_with_simple_plugin_builder
    FileUtils.cd(destination_root)
    run_generator([destination_root, "-b", "#{Rails.root}/lib/plugin_builders/simple_builder.rb"])
    (DEFAULT_PLUGIN_FILES - ['.gitignore']).each{ |path| assert_no_file path }
    assert_file ".gitignore", "foobar"
  end

  def test_builder_option_with_relative_path
    here = File.expand_path(File.dirname(__FILE__))
    FileUtils.cd(here)
    run_generator([destination_root, "-b", "../fixtures/lib/plugin_builders/simple_builder.rb"])
    FileUtils.cd(destination_root)
    (DEFAULT_PLUGIN_FILES - ['.gitignore']).each{ |path| assert_no_file path }
    assert_file ".gitignore", "foobar"
  end

  def test_builder_option_with_tweak_plugin_builder
    FileUtils.cd(destination_root)
    run_generator([destination_root, "-b", "#{Rails.root}/lib/plugin_builders/tweak_builder.rb"])
    DEFAULT_PLUGIN_FILES.each{ |path| assert_file path }
    assert_file ".gitignore", "foobar"
  end

  def test_builder_option_with_http
    path = "http://gist.github.com/103208.txt"
    template = "class PluginBuilder; end"
    template.instance_eval "def read; self; end" # Make the string respond to read

    generator([destination_root], :builder => path).expects(:open).with(path, 'Accept' => 'application/x-thor-template').returns(template)
    capture(:stdout) { generator.invoke_all }

    DEFAULT_PLUGIN_FILES.each{ |path| assert_no_file path }
  end

  def test_overriding_test_framework
    FileUtils.cd(destination_root)
    run_generator([destination_root, "-b", "#{Rails.root}/lib/plugin_builders/spec_builder.rb"])
    assert_file 'spec/spec_helper.rb'
    assert_file 'Rakefile', /task :default => :spec/
    assert_file 'Rakefile', /# spec tasks in rakefile/
    assert_file 'spec/dummy'
    assert_file 'script/rails', %r{spec/dummy}
  end

protected

  def action(*args, &block)
    silence(:stdout){ generator.send(*args, &block) }
  end
end
