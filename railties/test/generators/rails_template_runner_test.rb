require 'abstract_unit'
require 'generators/generator_test_helper'

class RailsTemplateRunnerTest < GeneratorTestCase
  def setup
    Rails::Generator::Base.use_application_sources!
    run_generator('app', [RAILS_ROOT])
    # generate empty template
    @template_path = File.join(RAILS_ROOT, 'template.rb')
    File.open(File.join(@template_path), 'w') {|f| f << '' }

    @git_plugin_uri = 'git://github.com/technoweenie/restful-authentication.git'
    @svn_plugin_uri = 'svn://svnhub.com/technoweenie/restful-authentication/trunk'
  end

  def teardown
    super
    rm_rf "#{RAILS_ROOT}/README"
    rm_rf "#{RAILS_ROOT}/Rakefile"
    rm_rf "#{RAILS_ROOT}/doc"
    rm_rf "#{RAILS_ROOT}/lib"
    rm_rf "#{RAILS_ROOT}/log"
    rm_rf "#{RAILS_ROOT}/script"
    rm_rf "#{RAILS_ROOT}/vendor"
    rm_rf "#{RAILS_ROOT}/tmp"
    rm_rf "#{RAILS_ROOT}/Capfile"
    rm_rf @template_path
  end

  def test_initialize_should_load_template
    Rails::TemplateRunner.any_instance.expects(:load_template).with(@template_path)
    silence_generator do
      Rails::TemplateRunner.new(@template_path, RAILS_ROOT)
    end
  end

  def test_initialize_should_raise_error_on_missing_template_file
    assert_raise(RuntimeError) do
      silence_generator do
        Rails::TemplateRunner.new('non/existent/path/to/template.rb', RAILS_ROOT)
      end
    end
  end

  def test_file_should_write_data_to_file_path
    run_template_method(:file, 'lib/test_file.rb', 'heres test data')
    assert_generated_file_with_data 'lib/test_file.rb', 'heres test data'
  end

  def test_file_should_write_block_contents_to_file_path
    run_template_method(:file, 'lib/test_file.rb') { 'heres block data' }
    assert_generated_file_with_data 'lib/test_file.rb', 'heres block data'
  end

  def test_plugin_with_git_option_should_run_plugin_install
    expects_run_ruby_script_with_command("script/plugin install #{@git_plugin_uri}")
    run_template_method(:plugin, 'restful-authentication', :git => @git_plugin_uri)
  end

  def test_plugin_with_svn_option_should_run_plugin_install
    expects_run_ruby_script_with_command("script/plugin install #{@svn_plugin_uri}")
    run_template_method(:plugin, 'restful-authentication', :svn => @svn_plugin_uri)
  end

  def test_plugin_with_git_option_and_submodule_should_use_git_scm
    Rails::Git.expects(:run).with("submodule add #{@git_plugin_uri} vendor/plugins/rest_auth")
    run_template_method(:plugin, 'rest_auth', :git => @git_plugin_uri, :submodule => true)
  end

  def test_plugin_with_no_options_should_skip_method
    Rails::TemplateRunner.any_instance.expects(:run).never
    run_template_method(:plugin, 'rest_auth', {})
  end

  def test_gem_should_put_gem_dependency_in_enviroment
    run_template_method(:gem, 'will-paginate')
    assert_rails_initializer_includes("config.gem 'will-paginate'")
  end

  def test_gem_with_options_should_include_options_in_gem_dependency_in_environment
    run_template_method(:gem, 'mislav-will-paginate', :lib => 'will-paginate', :source => 'http://gems.github.com')
    assert_rails_initializer_includes("config.gem 'mislav-will-paginate', :lib => 'will-paginate', :source => 'http://gems.github.com'")
  end

  def test_gem_with_env_string_should_put_gem_dependency_in_specified_environment
    run_template_method(:gem, 'rspec', :env => 'test')
    assert_generated_file_with_data('config/environments/test.rb', "config.gem 'rspec'", 'test')
  end

  def test_gem_with_env_array_should_put_gem_dependency_in_specified_environments
    run_template_method(:gem, 'quietbacktrace', :env => %w[ development test ])
    assert_generated_file_with_data('config/environments/development.rb', "config.gem 'quietbacktrace'")
    assert_generated_file_with_data('config/environments/test.rb', "config.gem 'quietbacktrace'")
  end

  def test_gem_with_lib_option_set_to_false_should_put_gem_dependency_in_enviroment_correctly
    run_template_method(:gem, 'mislav-will-paginate', :lib => false, :source => 'http://gems.github.com')
    assert_rails_initializer_includes("config.gem 'mislav-will-paginate', :lib => false, :source => 'http://gems.github.com'")
  end

  def test_environment_should_include_data_in_environment_initializer_block
    load_paths = 'config.load_paths += %w["#{RAILS_ROOT}/app/extras"]'
    run_template_method(:environment, load_paths)
    assert_rails_initializer_includes(load_paths)
  end

  def test_environment_with_block_should_include_block_contents_in_environment_initializer_block
    run_template_method(:environment) do
      '# This wont be added'
      '# This will be added'
    end
    assert_rails_initializer_includes('# This will be added')
  end

  def test_git_with_symbol_should_run_command_using_git_scm
    Rails::Git.expects(:run).once.with('init')
    run_template_method(:git, :init)
  end

  def test_git_with_hash_should_run_each_command_using_git_scm
    Rails::Git.expects(:run).times(2)
    run_template_method(:git, {:init => '', :add => '.'})
  end

  def test_vendor_should_write_data_to_file_in_vendor
    run_template_method(:vendor, 'vendor_file.rb', '# vendor data')
    assert_generated_file_with_data('vendor/vendor_file.rb', '# vendor data')
  end

  def test_lib_should_write_data_to_file_in_lib
    run_template_method(:lib, 'my_library.rb', 'class MyLibrary')
    assert_generated_file_with_data('lib/my_library.rb', 'class MyLibrary')
  end

  def test_rakefile_should_write_date_to_file_in_lib_tasks
    run_template_method(:rakefile, 'myapp.rake', 'task :run => [:environment]')
    assert_generated_file_with_data('lib/tasks/myapp.rake', 'task :run => [:environment]')
  end

  def test_initializer_should_write_date_to_file_in_config_initializers
    run_template_method(:initializer, 'constants.rb', 'MY_CONSTANT = 42')
    assert_generated_file_with_data('config/initializers/constants.rb', 'MY_CONSTANT = 42')
  end

  def test_generate_should_run_script_generate_with_argument_and_options
    expects_run_ruby_script_with_command('script/generate model MyModel')
    run_template_method(:generate, 'model', 'MyModel')
  end

  def test_rake_should_run_rake_command_with_development_env
    expects_run_with_command('rake log:clear RAILS_ENV=development')
    run_template_method(:rake, 'log:clear')
  end

  def test_rake_with_env_option_should_run_rake_command_in_env
    expects_run_with_command('rake log:clear RAILS_ENV=production')
    run_template_method(:rake, 'log:clear', :env => 'production')
  end

  def test_rake_with_sudo_option_should_run_rake_command_with_sudo
    expects_run_with_command('sudo rake log:clear RAILS_ENV=development')
    run_template_method(:rake, 'log:clear', :sudo => true)
  end

  def test_capify_should_run_the_capify_command
    expects_run_with_command('capify .')
    run_template_method(:capify!)
  end

  def test_freeze_should_freeze_rails_edge
    expects_run_with_command('rake rails:freeze:edge')
    run_template_method(:freeze!)
  end

  def test_route_should_add_data_to_the_routes_block_in_config_routes
    route_command = "map.route '/login', :controller => 'sessions', :action => 'new'"
    run_template_method(:route, route_command)
    assert_generated_file_with_data 'config/routes.rb', route_command
  end

  def test_run_ruby_script_should_add_ruby_to_command_in_win32_environment
    ruby_command = RUBY_PLATFORM =~ /win32/ ? 'ruby ' : ''
    expects_run_with_command("#{ruby_command}script/generate model MyModel")
    run_template_method(:generate, 'model', 'MyModel')
  end

  protected
  def run_template_method(method_name, *args, &block)
    silence_generator do
      @template_runner = Rails::TemplateRunner.new(@template_path, RAILS_ROOT)
      @template_runner.send(method_name, *args, &block)
    end
  end

  def expects_run_with_command(command)
    Rails::TemplateRunner.any_instance.stubs(:run).once.with(command, false)
  end

  def expects_run_ruby_script_with_command(command)
    Rails::TemplateRunner.any_instance.stubs(:run_ruby_script).once.with(command,false)
  end

  def assert_rails_initializer_includes(data, message = nil)
    message ||= "Rails::Initializer should include #{data}"
    assert_generated_file 'config/environment.rb' do |body|
      assert_match(/#{Regexp.escape("Rails::Initializer.run do |config|")}.+#{Regexp.escape(data)}.+end/m, body, message)
    end
  end

  def assert_generated_file_with_data(file, data, message = nil)
    message ||= "#{file} should include '#{data}'"
    assert_generated_file(file) do |file|
      assert_match(/#{Regexp.escape(data)}/,file, message)
    end
  end
end