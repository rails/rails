# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/app/app_generator"
require "env_helpers"

class ActionsTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  include EnvHelpers

  tests Rails::Generators::AppGenerator
  arguments [destination_root]

  def setup
    Rails.application = TestApp::Application
    super
  end

  def teardown
    Rails.application = TestApp::Application.instance
  end

  def test_invoke_other_generator_with_shortcut
    action :invoke, "model", ["my_model"]
    assert_file "app/models/my_model.rb", /MyModel/
  end

  def test_invoke_other_generator_with_full_namespace
    action :invoke, "rails:model", ["my_model"]
    assert_file "app/models/my_model.rb", /MyModel/
  end

  def test_create_file_should_write_data_to_file_path
    action :create_file, "lib/test_file.rb", "heres test data"
    assert_file "lib/test_file.rb", "heres test data"
  end

  def test_create_file_should_write_block_contents_to_file_path
    action(:create_file, "lib/test_file.rb") { "heres block data" }
    assert_file "lib/test_file.rb", "heres block data"
  end

  def test_add_source_adds_source_to_gemfile
    run_generator
    action :add_source, "http://gems.github.com"
    assert_file "Gemfile", /source 'http:\/\/gems\.github\.com'/
  end

  def test_add_source_with_block_adds_source_to_gemfile_with_gem
    run_generator
    action :add_source, "http://gems.github.com" do
      gem "rspec-rails"
    end
    assert_file "Gemfile", /source 'http:\/\/gems\.github\.com' do\n  gem 'rspec-rails'\nend/
  end

  def test_add_source_with_block_adds_source_to_gemfile_after_gem
    run_generator
    action :gem, "will-paginate"
    action :add_source, "http://gems.github.com" do
      gem "rspec-rails"
    end
    assert_file "Gemfile", /gem 'will-paginate'\nsource 'http:\/\/gems\.github\.com' do\n  gem 'rspec-rails'\nend/
  end

  def test_gem_should_put_gem_dependency_in_gemfile
    run_generator
    action :gem, "will-paginate"
    assert_file "Gemfile", /gem 'will\-paginate'/
  end

  def test_gem_with_version_should_include_version_in_gemfile
    run_generator
    action :gem, "rspec", ">= 2.0.0.a5"
    action :gem, "RedCloth", ">= 4.1.0", "< 4.2.0"
    action :gem, "nokogiri", version: ">= 1.4.2"
    action :gem, "faker", version: [">= 0.1.0", "< 0.3.0"]

    assert_file "Gemfile" do |content|
      assert_match(/gem 'rspec', '>= 2\.0\.0\.a5'/, content)
      assert_match(/gem 'RedCloth', '>= 4\.1\.0', '< 4\.2\.0'/, content)
      assert_match(/gem 'nokogiri', '>= 1\.4\.2'/, content)
      assert_match(/gem 'faker', '>= 0\.1\.0', '< 0\.3\.0'/, content)
    end
  end

  def test_gem_should_insert_on_separate_lines
    run_generator

    File.open("Gemfile", "a") { |f| f.write("# Some content...") }

    action :gem, "rspec"
    action :gem, "rspec-rails"

    assert_file "Gemfile", /^gem 'rspec'$/
    assert_file "Gemfile", /^gem 'rspec-rails'$/
  end

  def test_gem_should_include_options
    run_generator

    action :gem, "rspec", github: "dchelimsky/rspec", tag: "1.2.9.rc1"

    assert_file "Gemfile", /gem 'rspec', github: 'dchelimsky\/rspec', tag: '1\.2\.9\.rc1'/
  end

  def test_gem_with_non_string_options
    run_generator

    action :gem, "rspec", require: false
    action :gem, "rspec-rails", group: [:development, :test]

    assert_file "Gemfile", /^gem 'rspec', require: false$/
    assert_file "Gemfile", /^gem 'rspec-rails', group: \[:development, :test\]$/
  end

  def test_gem_falls_back_to_inspect_if_string_contains_single_quote
    run_generator

    action :gem, "rspec", ">=2.0'0"

    assert_file "Gemfile", /^gem 'rspec', ">=2\.0'0"$/
  end

  def test_gem_works_even_if_frozen_string_is_passed_as_argument
    run_generator

    action :gem, "frozen_gem".freeze, "1.0.0".freeze

    assert_file "Gemfile", /^gem 'frozen_gem', '1.0.0'$/
  end

  def test_gem_group_should_wrap_gems_in_a_group
    run_generator

    action :gem_group, :development, :test do
      gem "rspec-rails"
    end

    action :gem_group, :test do
      gem "fakeweb"
    end

    assert_file "Gemfile", /\ngroup :development, :test do\n  gem 'rspec-rails'\nend\n\ngroup :test do\n  gem 'fakeweb'\nend/
  end

  def test_environment_should_include_data_in_environment_initializer_block
    run_generator
    autoload_paths = 'config.autoload_paths += %w["#{Rails.root}/app/extras"]'
    action :environment, autoload_paths
    assert_file "config/application.rb", /  class Application < Rails::Application\n    #{Regexp.escape(autoload_paths)}\n/
  end

  def test_environment_should_include_data_in_environment_initializer_block_with_env_option
    run_generator
    autoload_paths = 'config.autoload_paths += %w["#{Rails.root}/app/extras"]'
    action :environment, autoload_paths, env: "development"
    assert_file "config/environments/development.rb", /Rails\.application\.configure do\n  #{Regexp.escape(autoload_paths)}\n/
  end

  def test_environment_with_block_should_include_block_contents_in_environment_initializer_block
    run_generator

    action :environment do
      _ = "# This wont be added"# assignment to silence parse-time warning "unused literal ignored"
      "# This will be added"
    end

    assert_file "config/application.rb" do |content|
      assert_match(/# This will be added/, content)
      assert_no_match(/# This wont be added/, content)
    end
  end

  def test_environment_with_block_should_include_block_contents_with_multiline_data_in_environment_initializer_block
    run_generator
    data = <<-RUBY
      config.encoding = "utf-8"
      config.time_zone = "UTC"
    RUBY
    action(:environment) { data }
    assert_file "config/application.rb", /  class Application < Rails::Application\n#{Regexp.escape(data.strip_heredoc.indent(4))}/
  end

  def test_environment_should_include_block_contents_with_multiline_data_in_environment_initializer_block_with_env_option
    run_generator
    data = <<-RUBY
      config.encoding = "utf-8"
      config.time_zone = "UTC"
    RUBY
    action(:environment, nil, env: "development") { data }
    assert_file "config/environments/development.rb", /Rails\.application\.configure do\n#{Regexp.escape(data.strip_heredoc.indent(2))}/
  end

  def test_git_with_symbol_should_run_command_using_git_scm
    assert_called_with(generator, :run, ["git init"]) do
      action :git, :init
    end
  end

  def test_git_with_hash_should_run_each_command_using_git_scm
    assert_called_with(generator, :run, [ ["git rm README"], ["git add ."] ]) do
      action :git, rm: "README", add: "."
    end
  end

  def test_vendor_should_write_data_to_file_in_vendor
    action :vendor, "vendor_file.rb", "# vendor data"
    assert_file "vendor/vendor_file.rb", "# vendor data\n"
  end

  def test_vendor_should_write_data_to_file_with_block_in_vendor
    code = <<-RUBY
      puts "one"
      puts "two"
      puts "three"
    RUBY
    action(:vendor, "vendor_file.rb") { code }
    assert_file "vendor/vendor_file.rb", code.strip_heredoc
  end

  def test_lib_should_write_data_to_file_in_lib
    action :lib, "my_library.rb", "class MyLibrary"
    assert_file "lib/my_library.rb", "class MyLibrary\n"
  end

  def test_lib_should_write_data_to_file_with_block_in_lib
    code = <<-RUBY
      class MyLib
        MY_CONSTANT = 123
      end
    RUBY
    action(:lib, "my_library.rb") { code }
    assert_file "lib/my_library.rb", code.strip_heredoc
  end

  def test_rakefile_should_write_date_to_file_in_lib_tasks
    action :rakefile, "myapp.rake", "task run: [:environment]"
    assert_file "lib/tasks/myapp.rake", "task run: [:environment]\n"
  end

  def test_rakefile_should_write_date_to_file_with_block_in_lib_tasks
    code = <<-RUBY
      task rock: :environment do
        puts "Rockin'"
      end
    RUBY
    action(:rakefile, "myapp.rake") { code }
    assert_file "lib/tasks/myapp.rake", code.strip_heredoc
  end

  def test_initializer_should_write_date_to_file_in_config_initializers
    action :initializer, "constants.rb", "MY_CONSTANT = 42"
    assert_file "config/initializers/constants.rb", "MY_CONSTANT = 42\n"
  end

  def test_initializer_should_write_date_to_file_with_block_in_config_initializers
    code = <<-RUBY
      MyLib.configure do |config|
        config.value = 123
      end
    RUBY
    action(:initializer, "constants.rb") { code }
    assert_file "config/initializers/constants.rb", code.strip_heredoc
  end

  def test_generate_should_run_script_generate_with_argument_and_options
    assert_called_with(generator, :run_ruby_script, ["bin/rails generate model MyModel", verbose: false]) do
      action :generate, "model", "MyModel"
    end
  end

  def test_rails_should_run_rake_command_with_default_env
    assert_called_with(generator, :run, ["rake log:clear RAILS_ENV=development", verbose: false]) do
      with_rails_env nil do
        action :rake, "log:clear"
      end
    end
  end

  def test_rails_with_env_option_should_run_rake_command_in_env
    assert_called_with(generator, :run, ["rake log:clear RAILS_ENV=production", verbose: false]) do
      action :rake, "log:clear", env: "production"
    end
  end

  test "rails command with RAILS_ENV variable should run rake command in env" do
    assert_called_with(generator, :run, ["rake log:clear RAILS_ENV=production", verbose: false]) do
      with_rails_env "production" do
        action :rake, "log:clear"
      end
    end
  end

  test "env option should win over RAILS_ENV variable when running rake" do
    assert_called_with(generator, :run, ["rake log:clear RAILS_ENV=production", verbose: false]) do
      with_rails_env "staging" do
        action :rake, "log:clear", env: "production"
      end
    end
  end

  test "rails command with sudo option should run rake command with sudo" do
    assert_called_with(generator, :run, ["sudo rake log:clear RAILS_ENV=development", verbose: false]) do
      with_rails_env nil do
        action :rake, "log:clear", sudo: true
      end
    end
  end

  test "rake command with capture option should run rake command with capture" do
    assert_called_with(generator, :run, ["rake log:clear RAILS_ENV=development", verbose: false, capture: true]) do
      with_rails_env nil do
        action :rake, "log:clear", capture: true
      end
    end
  end

  test "rails command should run rails_command with default env" do
    assert_called_with(generator, :run, ["rails log:clear RAILS_ENV=development", verbose: false]) do
      with_rails_env nil do
        action :rails_command, "log:clear"
      end
    end
  end

  test "rails command with env option should run rails_command with same env" do
    assert_called_with(generator, :run, ["rails log:clear RAILS_ENV=production", verbose: false]) do
      action :rails_command, "log:clear", env: "production"
    end
  end

  test "rails command with RAILS_ENV variable should run rails_command in env" do
    assert_called_with(generator, :run, ["rails log:clear RAILS_ENV=production", verbose: false]) do
      with_rails_env "production" do
        action :rails_command, "log:clear"
      end
    end
  end

  def test_env_option_should_win_over_rails_env_variable_when_running_rails
    assert_called_with(generator, :run, ["rails log:clear RAILS_ENV=production", verbose: false]) do
      with_rails_env "staging" do
        action :rails_command, "log:clear", env: "production"
      end
    end
  end

  test "rails command with sudo option should run rails_command with sudo" do
    assert_called_with(generator, :run, ["sudo rails log:clear RAILS_ENV=development", verbose: false]) do
      with_rails_env nil do
        action :rails_command, "log:clear", sudo: true
      end
    end
  end

  test "rails command with capture option should run rails_command with capture" do
    assert_called_with(generator, :run, ["rails log:clear RAILS_ENV=development", verbose: false, capture: true]) do
      with_rails_env nil do
        action :rails_command, "log:clear", capture: true
      end
    end
  end

  def test_capify_should_run_the_capify_command
    content = capture(:stderr) do
      assert_called_with(generator, :run, ["capify .", verbose: false]) do
        action :capify!
      end
    end
    assert_match(/DEPRECATION WARNING: `capify!` is deprecated/, content)
  end

  def test_route_should_add_data_to_the_routes_block_in_config_routes
    run_generator
    route_command = "route '/login', controller: 'sessions', action: 'new'"
    action :route, route_command
    assert_file "config/routes.rb", /#{Regexp.escape(route_command)}/
  end

  def test_route_should_be_idempotent
    run_generator
    route_path = File.expand_path("config/routes.rb", destination_root)

    # runs first time, not asserting
    action :route, "root 'welcome#index'"
    content_1 = File.read(route_path)

    # runs second time
    action :route, "root 'welcome#index'"
    content_2 = File.read(route_path)

    assert_equal content_1, content_2
  end

  def test_route_should_add_data_with_an_new_line
    run_generator
    action :route, "root 'welcome#index'"
    route_path = File.expand_path("config/routes.rb", destination_root)
    content = File.read(route_path)

    # Remove all of the comments and blank lines from the routes file
    content.gsub!(/^  \#.*\n/, "")
    content.gsub!(/^\n/, "")

    File.write(route_path, content)

    routes = <<-F
Rails.application.routes.draw do
  root 'welcome#index'
end
F

    assert_file "config/routes.rb", routes

    action :route, "resources :product_lines"

    routes = <<-F
Rails.application.routes.draw do
  resources :product_lines
  root 'welcome#index'
end
F
    assert_file "config/routes.rb", routes
  end

  def test_readme
    run_generator
    assert_called(Rails::Generators::AppGenerator, :source_root, times: 2, returns: destination_root) do
      assert_match "application up and running", action(:readme, "README.md")
    end
  end

  def test_readme_with_quiet
    generator(default_arguments, quiet: true)
    run_generator
    assert_called(Rails::Generators::AppGenerator, :source_root, times: 2, returns: destination_root) do
      assert_no_match "application up and running", action(:readme, "README.md")
    end
  end

  def test_log
    assert_equal("YES\n", action(:log, "YES"))
  end

  def test_log_with_status
    assert_equal("         yes  YES\n", action(:log, :yes, "YES"))
  end

  def test_log_with_quiet
    generator(default_arguments, quiet: true)
    assert_equal("", action(:log, "YES"))
  end

  def test_log_with_status_with_quiet
    generator(default_arguments, quiet: true)
    assert_equal("", action(:log, :yes, "YES"))
  end

  def test_open_file_in_editor
    generator(default_arguments, editor: "cat")

    assert_called_with(generator, :run, ["cat Gemfile"]) do
      action :open_file_in_editor, "Gemfile"
    end
  end

  private

    def action(*args, &block)
      capture(:stdout) { generator.send(*args, &block) }
    end
end
