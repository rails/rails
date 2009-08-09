require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/app/app_generator'

class ActionsTest < GeneratorsTestCase
  def setup
    super
    @git_plugin_uri = 'git://github.com/technoweenie/restful-authentication.git'
    @svn_plugin_uri = 'svn://svnhub.com/technoweenie/restful-authentication/trunk'
  end

  def test_create_file_should_write_data_to_file_path
    action :create_file, 'lib/test_file.rb', 'heres test data'
    assert_file 'lib/test_file.rb', 'heres test data'
  end

  def test_create_file_should_write_block_contents_to_file_path
    action(:create_file, 'lib/test_file.rb'){ 'heres block data' }
    assert_file 'lib/test_file.rb', 'heres block data'
  end

  def test_plugin_with_git_option_should_run_plugin_install
    generator.expects(:run_ruby_script).once.with("script/plugin install #{@git_plugin_uri}", :verbose => false)
    action :plugin, 'restful-authentication', :git => @git_plugin_uri
  end

  def test_plugin_with_svn_option_should_run_plugin_install
    generator.expects(:run_ruby_script).once.with("script/plugin install #{@svn_plugin_uri}", :verbose => false)
    action :plugin, 'restful-authentication', :svn => @svn_plugin_uri
  end

  def test_plugin_with_git_option_and_branch_should_run_plugin_install
    generator.expects(:run_ruby_script).once.with("script/plugin install -b stable #{@git_plugin_uri}", :verbose => false)
    action :plugin, 'restful-authentication', :git => @git_plugin_uri, :branch => 'stable'
  end

  def test_plugin_with_svn_option_and_revision_should_run_plugin_install
    generator.expects(:run_ruby_script).once.with("script/plugin install -r 1234 #{@svn_plugin_uri}", :verbose => false)
    action :plugin, 'restful-authentication', :svn => @svn_plugin_uri, :revision => 1234
  end

  def test_plugin_with_git_option_and_submodule_should_use_git_scm
    generator.expects(:run).with("git submodule add #{@git_plugin_uri} vendor/plugins/rest_auth", :verbose => false)
    action :plugin, 'rest_auth', :git => @git_plugin_uri, :submodule => true
  end

  def test_plugin_with_git_option_and_submodule_should_use_git_scm
    generator.expects(:run).with("git submodule add -b stable #{@git_plugin_uri} vendor/plugins/rest_auth", :verbose => false)
    action :plugin, 'rest_auth', :git => @git_plugin_uri, :submodule => true, :branch => 'stable'
  end

  def test_plugin_with_no_options_should_skip_method
    generator.expects(:run).never
    action :plugin, 'rest_auth', {}
  end

  def test_gem_should_put_gem_dependency_in_enviroment
    run_generator
    action :gem, 'will-paginate'
    assert_file 'config/environment.rb', /config\.gem 'will\-paginate'/
  end

  def test_gem_with_options_should_include_options_in_gem_dependency_in_environment
    run_generator
    action :gem, 'mislav-will-paginate', :lib => 'will-paginate', :source => 'http://gems.github.com'

    regexp = /#{Regexp.escape("config.gem 'mislav-will-paginate', :lib => 'will-paginate', :source => 'http://gems.github.com'")}/
    assert_file 'config/environment.rb', regexp
  end

  def test_gem_with_env_string_should_put_gem_dependency_in_specified_environment
    run_generator
    action :gem, 'rspec', :env => 'test'
    assert_file 'config/environments/test.rb', /config\.gem 'rspec'/
  end

  def test_gem_with_env_array_should_put_gem_dependency_in_specified_environments
    run_generator
    action :gem, 'quietbacktrace', :env => %w[ development test ]
    assert_file 'config/environments/development.rb', /config\.gem 'quietbacktrace'/
    assert_file 'config/environments/test.rb', /config\.gem 'quietbacktrace'/
  end

  def test_gem_with_lib_option_set_to_false_should_put_gem_dependency_in_enviroment_correctly
    run_generator
    action :gem, 'mislav-will-paginate', :lib => false
    assert_file 'config/environment.rb', /config\.gem 'mislav\-will\-paginate'\, :lib => false/
  end

  def test_environment_should_include_data_in_environment_initializer_block
    run_generator
    load_paths = 'config.load_paths += %w["#{RAILS_ROOT}/app/extras"]'
    action :environment, load_paths
    assert_file 'config/environment.rb', /#{Regexp.escape(load_paths)}/
  end

  def test_environment_with_block_should_include_block_contents_in_environment_initializer_block
    run_generator

    action :environment do
      '# This wont be added'
      '# This will be added'
    end

    assert_file 'config/environment.rb' do |content|
      assert_match /# This will be added/, content
      assert_no_match /# This wont be added/, content
    end
  end

  def test_git_with_symbol_should_run_command_using_git_scm
    generator.expects(:run).once.with('git init')
    action :git, :init
  end

  def test_git_with_hash_should_run_each_command_using_git_scm
    generator.expects(:run).times(2)
    action :git, :rm => 'README', :add => '.'
  end

  def test_vendor_should_write_data_to_file_in_vendor
    action :vendor, 'vendor_file.rb', '# vendor data'
    assert_file 'vendor/vendor_file.rb', '# vendor data'
  end

  def test_lib_should_write_data_to_file_in_lib
    action :lib, 'my_library.rb', 'class MyLibrary'
    assert_file 'lib/my_library.rb', 'class MyLibrary'
  end

  def test_rakefile_should_write_date_to_file_in_lib_tasks
    action :rakefile, 'myapp.rake', 'task :run => [:environment]'
    assert_file 'lib/tasks/myapp.rake', 'task :run => [:environment]'
  end

  def test_initializer_should_write_date_to_file_in_config_initializers
    action :initializer, 'constants.rb', 'MY_CONSTANT = 42'
    assert_file 'config/initializers/constants.rb', 'MY_CONSTANT = 42'
  end

  def test_generate_should_run_script_generate_with_argument_and_options
    generator.expects(:run_ruby_script).once.with('script/generate model MyModel', :verbose => false)
    action :generate, 'model', 'MyModel'
  end

  def test_rake_should_run_rake_command_with_development_env
    generator.expects(:run).once.with('rake log:clear RAILS_ENV=development', :verbose => false)
    action :rake, 'log:clear'
  end

  def test_rake_with_env_option_should_run_rake_command_in_env
    generator.expects(:run).once.with('rake log:clear RAILS_ENV=production', :verbose => false)
    action :rake, 'log:clear', :env => 'production'
  end

  def test_rake_with_sudo_option_should_run_rake_command_with_sudo
    generator.expects(:run).once.with('sudo rake log:clear RAILS_ENV=development', :verbose => false)
    action :rake, 'log:clear', :sudo => true
  end

  def test_capify_should_run_the_capify_command
    generator.expects(:run).once.with('capify .', :verbose => false)
    action :capify!
  end

  def test_freeze_should_freeze_rails_edge
    generator.expects(:run).once.with('rake rails:freeze:edge', :verbose => false)
    action :freeze!
  end

  def test_route_should_add_data_to_the_routes_block_in_config_routes
    run_generator
    route_command = "map.route '/login', :controller => 'sessions', :action => 'new'"
    action :route, route_command
    assert_file 'config/routes.rb', /#{Regexp.escape(route_command)}/
  end

  protected

    def run_generator
      silence(:stdout) { Rails::Generators::AppGenerator.start [destination_root] }
    end

    def generator(config={})
      @generator ||= Rails::Generators::Base.new([], {}, { :destination_root => destination_root }.merge!(config))
    end

    def action(*args, &block)
      silence(:stdout){ generator.send(*args, &block) }
    end

end
