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
    action :create_file, "lib/test_file.rb", "here's test data"
    assert_file "lib/test_file.rb", "here's test data"
  end

  def test_create_file_should_write_block_contents_to_file_path
    action(:create_file, "lib/test_file.rb") { "here's block data" }
    assert_file "lib/test_file.rb", "here's block data"
  end

  def test_add_source_adds_source_to_gemfile
    run_generator
    action :add_source, "http://gems.github.com"
    assert_file "Gemfile", /source 'http:\/\/gems\.github\.com'\n/
  end

  def test_add_source_with_block_adds_source_to_gemfile_with_gem
    run_generator
    action :add_source, "http://gems.github.com" do
      gem "rspec-rails"
    end
    assert_file "Gemfile", /\n\nsource 'http:\/\/gems\.github\.com' do\n  gem 'rspec-rails'\nend\n\z/
  end

  def test_add_source_with_block_adds_source_to_gemfile_after_gem
    run_generator
    action :gem, "will-paginate"
    action :add_source, "http://gems.github.com" do
      gem "rspec-rails"
    end
    assert_file "Gemfile", /\ngem 'will-paginate'\n\nsource 'http:\/\/gems\.github\.com' do\n  gem 'rspec-rails'\nend\n\z/
  end

  def test_add_source_should_create_newline_between_blocks
    run_generator
    action :add_source, "http://gems.github.com" do
      gem "rspec-rails"
    end

    action :add_source, "http://gems2.github.com" do
      gem "fakeweb"
    end
    assert_file "Gemfile", /\n\nsource 'http:\/\/gems\.github\.com' do\n  gem 'rspec-rails'\nend\n\nsource 'http:\/\/gems2\.github\.com' do\n  gem 'fakeweb'\nend\n\z/
  end

  def test_gem_should_put_gem_dependency_in_gemfile
    run_generator
    action :gem, "will-paginate"
    assert_file "Gemfile", /gem 'will-paginate'\n\z/
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

    action :gem, -"frozen_gem", -"1.0.0"

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

    assert_file "Gemfile", /\n\ngroup :development, :test do\n  gem 'rspec-rails'\nend\n\ngroup :test do\n  gem 'fakeweb'\nend\n\z/
  end

  def test_github_should_create_an_indented_block
    run_generator

    action :github, "user/repo" do
      gem "foo"
      gem "bar"
      gem "baz"
    end

    assert_file "Gemfile", /\n\ngithub 'user\/repo' do\n  gem 'foo'\n  gem 'bar'\n  gem 'baz'\nend\n\z/
  end

  def test_github_should_create_an_indented_block_with_options
    run_generator

    action :github, "user/repo", a: "correct", other: true do
      gem "foo"
      gem "bar"
      gem "baz"
    end

    assert_file "Gemfile", /\n\ngithub 'user\/repo', a: 'correct', other: true do\n  gem 'foo'\n  gem 'bar'\n  gem 'baz'\nend\n\z/
  end

  def test_github_should_create_an_indented_block_within_a_group
    run_generator

    action :gem_group, :magic do
      github "user/repo", a: "correct", other: true do
        gem "foo"
        gem "bar"
        gem "baz"
      end
      github "user/repo2", a: "correct", other: true do
        gem "foo"
        gem "bar"
        gem "baz"
      end
    end

    assert_file "Gemfile", /\n\ngroup :magic do\n  github 'user\/repo', a: 'correct', other: true do\n    gem 'foo'\n    gem 'bar'\n    gem 'baz'\n  end\n  github 'user\/repo2', a: 'correct', other: true do\n    gem 'foo'\n    gem 'bar'\n    gem 'baz'\n  end\nend\n\z/
  end

  def test_github_should_create_newline_between_blocks
    run_generator

    action :github, "user/repo", a: "correct", other: true do
      gem "foo"
      gem "bar"
      gem "baz"
    end

    action :github, "user/repo2", a: "correct", other: true do
      gem "foo"
      gem "bar"
      gem "baz"
    end

    assert_file "Gemfile", /\n\ngithub 'user\/repo', a: 'correct', other: true do\n  gem 'foo'\n  gem 'bar'\n  gem 'baz'\nend\n\ngithub 'user\/repo2', a: 'correct', other: true do\n  gem 'foo'\n  gem 'bar'\n  gem 'baz'\nend\n\z/
  end

  def test_gem_with_gemfile_without_newline_at_the_end
    run_generator
    File.open("Gemfile", "a") { |f| f.write("gem 'rspec-rails'") }

    action :gem, "will-paginate"
    assert_file "Gemfile", /gem 'rspec-rails'\ngem 'will-paginate'\n\z/
  end

  def test_gem_group_with_gemfile_without_newline_at_the_end
    run_generator
    File.open("Gemfile", "a") { |f| f.write("gem 'rspec-rails'") }

    action :gem_group, :test do
      gem "fakeweb"
    end

    assert_file "Gemfile", /gem 'rspec-rails'\n\ngroup :test do\n  gem 'fakeweb'\nend\n\z/
  end

  def test_add_source_with_gemfile_without_newline_at_the_end
    run_generator
    File.open("Gemfile", "a") { |f| f.write("gem 'rspec-rails'") }

    action :add_source, "http://gems.github.com" do
      gem "fakeweb"
    end

    assert_file "Gemfile", /gem 'rspec-rails'\n\nsource 'http:\/\/gems\.github\.com' do\n  gem 'fakeweb'\nend\n\z/
  end

  def test_github_with_gemfile_without_newline_at_the_end
    run_generator
    File.open("Gemfile", "a") { |f| f.write("gem 'rspec-rails'") }

    action :github, "user/repo" do
      gem "fakeweb"
    end

    assert_file "Gemfile", /gem 'rspec-rails'\n\ngithub 'user\/repo' do\n  gem 'fakeweb'\nend\n\z/
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
      _ = "# This wont be added" # assignment to silence parse-time warning "unused literal ignored"
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
    assert_runs "git init", nil do
      action :git, :init
    end
  end

  def test_git_with_hash_should_run_each_command_using_git_scm
    assert_runs ["git rm README", "git add ."], nil do
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

  test "generate" do
    run_generator
    action :generate, "model", "MyModel"
    assert_file "app/models/my_model.rb", /MyModel/
  end

  test "generate should raise on failure" do
    run_generator
    message = capture(:stderr) do
      assert_raises SystemExit do
        action :generate, "model", "1234567890"
      end
    end
    assert_match(/1234567890/, message)
  end

  test "generate with inline option" do
    run_generator
    assert_not_called(generator, :run) do
      action :generate, "model", "MyModel", inline: true
    end
    assert_file "app/models/my_model.rb", /MyModel/
  end

  test "generate with inline option should raise on failure" do
    run_generator
    error = assert_raises do
      action :generate, "model", "1234567890", inline: true
    end
    assert_match(/1234567890/, error.message)
  end

  test "rake should run rake with the default environment" do
    assert_runs "rake log:clear", env: { "RAILS_ENV" => "development" } do
      with_rails_env nil do
        action :rake, "log:clear"
      end
    end
  end

  test "rake with env option should run rake with the env environment" do
    assert_runs "rake log:clear", env: { "RAILS_ENV" => "production" } do
      action :rake, "log:clear", env: "production"
    end
  end

  test "rake with RAILS_ENV set should run rake with the RAILS_ENV environment" do
    assert_runs "rake log:clear", env: { "RAILS_ENV" => "production" } do
      with_rails_env "production" do
        action :rake, "log:clear"
      end
    end
  end

  test "rake with env option and RAILS_ENV set should run rake with the env environment" do
    assert_runs "rake log:clear", env: { "RAILS_ENV" => "production" } do
      with_rails_env "staging" do
        action :rake, "log:clear", env: "production"
      end
    end
  end

  test "rake with sudo option should run rake with sudo" do
    assert_runs "sudo rake log:clear" do
      action :rake, "log:clear", sudo: true
    end
  end

  test "rake with capture option should run rake with capture" do
    assert_runs "rake log:clear", capture: true do
      action :rake, "log:clear", capture: true
    end
  end

  test "rake with abort_on_failure option should raise on failure" do
    capture(:stderr) do
      assert_raises SystemExit do
        action :rake, "invalid", abort_on_failure: true
      end
    end
  end

  test "rails_command should run rails with the default environment" do
    assert_runs "rails log:clear", env: { "RAILS_ENV" => "development" } do
      with_rails_env nil do
        action :rails_command, "log:clear"
      end
    end
  end

  test "rails_command with env option should run rails with the env environment" do
    assert_runs "rails log:clear", env: { "RAILS_ENV" => "production" } do
      action :rails_command, "log:clear", env: "production"
    end
  end

  test "rails_command with RAILS_ENV set should run rails with the RAILS_ENV environment" do
    assert_runs "rails log:clear", env: { "RAILS_ENV" => "production" } do
      with_rails_env "production" do
        action :rails_command, "log:clear"
      end
    end
  end

  test "rails_command with env option and RAILS_ENV set should run rails with the env environment" do
    assert_runs "rails log:clear", env: { "RAILS_ENV" => "production" } do
      with_rails_env "staging" do
        action :rails_command, "log:clear", env: "production"
      end
    end
  end

  test "rails_command with sudo option should run rails with sudo" do
    assert_runs "sudo rails log:clear" do
      with_rails_env nil do
        action :rails_command, "log:clear", sudo: true
      end
    end
  end

  test "rails_command with capture option should run rails with capture" do
    assert_runs "rails log:clear", capture: true do
      with_rails_env nil do
        action :rails_command, "log:clear", capture: true
      end
    end
  end

  test "rails_command with abort_on_failure option should raise on failure" do
    run_generator
    capture(:stderr) do
      assert_raises SystemExit do
        action :rails_command, "invalid", abort_on_failure: true
      end
    end
  end

  test "rails_command with inline option" do
    run_generator
    assert_not_called(generator, :run) do
      action :rails_command, "generate model MyModel", inline: true
    end
    assert_file "app/models/my_model.rb", /MyModel/
  end

  test "rails_command with inline option should raise on failure" do
    run_generator
    error = assert_raises do
      action :rails_command, "generate model 1234567890", inline: true
    end
    assert_match(/1234567890/, error.message)
  end

  test "route should add route" do
    run_generator
    route_commands = ["get 'foo'", "get 'bar'", "get 'baz'"]
    route_commands.each do |route_command|
      action :route, route_command
    end
    assert_routes route_commands
  end

  test "route should indent routing code" do
    run_generator
    route_commands = ["get 'foo'", "get 'bar'", "get 'baz'"]
    action :route, route_commands.join("\n")
    assert_routes route_commands
  end

  test "route should be idempotent" do
    run_generator
    route_command = "root 'welcome#index'"

    # runs first time
    action :route, route_command
    assert_routes route_command

    content = File.read(File.expand_path("config/routes.rb", destination_root))

    # runs second time
    action :route, route_command
    assert_file "config/routes.rb", content
  end

  test "route with namespace option should nest route" do
    run_generator
    action :route, "get 'foo'\nget 'bar'", namespace: :baz
    assert_routes <<~ROUTING_CODE.chomp
      namespace :baz do
        get 'foo'
        get 'bar'
      end
    ROUTING_CODE
  end

  test "route with namespace option array should deeply nest route" do
    run_generator
    action :route, "get 'foo'\nget 'bar'", namespace: %w[baz qux]
    assert_routes <<~ROUTING_CODE.chomp
      namespace :baz do
        namespace :qux do
          get 'foo'
          get 'bar'
        end
      end
    ROUTING_CODE
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

  private
    def action(*args, **kwargs, &block)
      capture(:stdout) { generator.send(*args, **kwargs, &block) }
    end

    def assert_runs(commands, config = {}, &block)
      config_matcher = ->(actual_config) do
        assert_equal config, actual_config.slice(*config.keys)
      end if config
      args = Array(commands).map { |command| [command, *config_matcher] }

      assert_called_with(generator, :run, args) do
        block.call
      end
    end

    def assert_routes(*route_commands)
      route_regexps = route_commands.flatten.map do |route_command|
        %r{
          ^#{Regexp.escape("Rails.application.routes.draw do")}\n
            (?:[ ]{2}.+\n|\n)*
            #{Regexp.escape(route_command.indent(2))}\n
            (?:[ ]{2}.+\n|\n)*
          end\n
        }x
      end

      assert_file "config/routes.rb", *route_regexps
    end
end
