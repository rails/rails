require 'generators/generators_test_helper'
require 'rails/generators/rails/plugin/plugin_generator'
require 'generators/shared_generator_tests'

DEFAULT_PLUGIN_FILES = %w(
  .gitignore
  Gemfile
  Rakefile
  README.rdoc
  bukkits.gemspec
  MIT-LICENSE
  lib
  lib/bukkits.rb
  lib/tasks/bukkits_tasks.rake
  lib/bukkits/version.rb
  test/bukkits_test.rb
  test/test_helper.rb
  test/dummy
)

class PluginGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  destination File.join(Rails.root, "tmp/bukkits")
  arguments [destination_root]

  # brings setup, teardown, and some tests
  include SharedGeneratorTests

  def test_invalid_plugin_name_raises_an_error
    content = capture(:stderr){ run_generator [File.join(destination_root, "things-43")] }
    assert_equal "Invalid plugin name things-43. Please give a name which use only alphabetic or numeric or \"_\" characters.\n", content

    content = capture(:stderr){ run_generator [File.join(destination_root, "things4.3")] }
    assert_equal "Invalid plugin name things4.3. Please give a name which use only alphabetic or numeric or \"_\" characters.\n", content

    content = capture(:stderr){ run_generator [File.join(destination_root, "43things")] }
    assert_equal "Invalid plugin name 43things. Please give a name which does not start with numbers.\n", content

    content = capture(:stderr){ run_generator [File.join(destination_root, "plugin")] }
    assert_equal "Invalid plugin name plugin. Please give a name which does not match one of the reserved rails words.\n", content

    content = capture(:stderr){ run_generator [File.join(destination_root, "Digest")] }
    assert_equal "Invalid plugin name Digest, constant Digest is already in use. Please choose another plugin name.\n", content
  end

  def test_camelcase_plugin_name_underscores_filenames
    run_generator [File.join(destination_root, "CamelCasedName")]
    assert_no_file "CamelCasedName/lib/CamelCasedName.rb"
    assert_file "CamelCasedName/lib/camel_cased_name.rb", /module CamelCasedName/
  end

  def test_generating_without_options
    run_generator
    assert_file "README.rdoc", /Bukkits/
    assert_no_file "config/routes.rb"
    assert_file "test/test_helper.rb" do |content|
      assert_match(/require.+test\/dummy\/config\/environment/, content)
      assert_match(/ActiveRecord::Migrator\.migrations_paths.+test\/dummy\/db\/migrate/, content)
      assert_match(/Minitest\.backtrace_filter = Minitest::BacktraceFilter\.new/, content)
    end
    assert_file "test/bukkits_test.rb", /assert_kind_of Module, Bukkits/
  end

  def test_generating_test_files_in_full_mode
    run_generator [destination_root, "--full"]
    assert_directory "test/integration/"

    assert_file "test/integration/navigation_test.rb", /ActionDispatch::IntegrationTest/
  end

  def test_inclusion_of_debugger
    run_generator [destination_root, '--full']
    if defined?(JRUBY_VERSION)
      assert_file "Gemfile" do |content|
        assert_no_match(/debugger/, content)
      end
    else
      assert_file "Gemfile", /# gem 'debugger'/
    end
  end

  def test_generating_test_files_in_full_mode_without_unit_test_files
    run_generator [destination_root, "-T", "--full"]

    assert_no_directory "test/integration/"
    assert_no_file "test"
    assert_file "Rakefile" do |contents|
      assert_no_match(/APP_RAKEFILE/, contents)
    end
  end

  def test_generating_adds_dummy_app_rake_tasks_without_unit_test_files
    run_generator [destination_root, "-T", "--mountable", '--dummy-path', 'my_dummy_app']
    assert_file "Rakefile", /APP_RAKEFILE/
  end

  def test_generating_adds_dummy_app_without_javascript_and_assets_deps
    run_generator [destination_root]

    assert_file "test/dummy/app/assets/stylesheets/application.css"

    assert_file "test/dummy/app/assets/javascripts/application.js" do |contents|
      assert_no_match(/jquery/, contents)
    end
  end

  def test_ensure_that_plugin_options_are_not_passed_to_app_generator
    FileUtils.cd(Rails.root)
    assert_no_match(/It works from file!.*It works_from_file/, run_generator([destination_root, "-m", "lib/template.rb"]))
  end

  def test_ensure_that_test_dummy_can_be_generated_from_a_template
    FileUtils.cd(Rails.root)
    run_generator([destination_root, "-m", "lib/create_test_dummy_template.rb", "--skip-test-unit"])
    assert_file "spec/dummy"
    assert_no_file "test"
  end

  def test_database_entry_is_generated_for_sqlite3_by_default_in_full_mode
    run_generator([destination_root, "--full"])
    assert_file "test/dummy/config/database.yml", /sqlite/
    assert_file "bukkits.gemspec", /sqlite3/
  end

  def test_config_another_database
    run_generator([destination_root, "-d", "mysql", "--full"])
    assert_file "test/dummy/config/database.yml", /mysql/
    assert_file "bukkits.gemspec", /mysql/
  end

  def test_dont_generate_development_dependency
    run_generator [destination_root, "--skip-active-record"]

    assert_file "bukkits.gemspec" do |contents|
      assert_no_match(/s.add_development_dependency "sqlite3"/, contents)
    end
  end

  def test_active_record_is_removed_from_frameworks_if_skip_active_record_is_given
    run_generator [destination_root, "--skip-active-record"]
    assert_file "test/dummy/config/application.rb", /#\s+require\s+["']active_record\/railtie["']/
  end

  def test_ensure_that_skip_active_record_option_is_passed_to_app_generator
    run_generator [destination_root, "--skip_active_record"]
    assert_no_file "test/dummy/config/database.yml"
    assert_file "test/test_helper.rb" do |contents|
      assert_no_match(/ActiveRecord/, contents)
    end
  end

  def test_ensure_that_database_option_is_passed_to_app_generator
    run_generator [destination_root, "--database", "postgresql"]
    assert_file "test/dummy/config/database.yml", /postgres/
  end

  def test_generation_runs_bundle_install_with_full_and_mountable
    result = run_generator [destination_root, "--mountable", "--full", "--dev"]
    assert_match(/run  bundle install/, result)
    assert $?.success?, "Command failed: #{result}"
    assert_file "#{destination_root}/Gemfile.lock" do |contents|
      assert_match(/bukkits/, contents)
    end
  end

  def test_skipping_javascripts_without_mountable_option
    run_generator
    assert_no_file "app/assets/javascripts/bukkits/application.js"
  end

  def test_javascripts_generation
    run_generator [destination_root, "--mountable"]
    assert_file "app/assets/javascripts/bukkits/application.js"
  end

  def test_skip_javascripts
    run_generator [destination_root, "--skip-javascript", "--mountable"]
    assert_no_file "app/assets/javascripts/bukkits/application.js"
  end

  def test_template_from_dir_pwd
    FileUtils.cd(Rails.root)
    assert_match(/It works from file!/, run_generator([destination_root, "-m", "lib/template.rb"]))
  end

  def test_ensure_that_tests_work
    run_generator
    FileUtils.cd destination_root
    quietly { system 'bundle install' }
    assert_match(/1 runs, 1 assertions, 0 failures, 0 errors/, `bundle exec rake test 2>&1`)
  end

  def test_ensure_that_tests_works_in_full_mode
    run_generator [destination_root, "--full", "--skip_active_record"]
    FileUtils.cd destination_root
    quietly { system 'bundle install' }
    assert_match(/1 runs, 1 assertions, 0 failures, 0 errors/, `bundle exec rake test 2>&1`)
  end

  def test_ensure_that_migration_tasks_work_with_mountable_option
    run_generator [destination_root, "--mountable"]
    FileUtils.cd destination_root
    quietly { system 'bundle install' }
    output = `bundle exec rake db:migrate 2>&1`
    assert $?.success?, "Command failed: #{output}"
  end

  def test_creating_engine_in_full_mode
    run_generator [destination_root, "--full"]
    assert_file "app/assets/javascripts/bukkits"
    assert_file "app/assets/stylesheets/bukkits"
    assert_file "app/assets/images/bukkits"
    assert_file "app/models"
    assert_file "app/controllers"
    assert_file "app/views"
    assert_file "app/helpers"
    assert_file "app/mailers"
    assert_file "bin/rails"
    assert_file "config/routes.rb", /Rails.application.routes.draw do/
    assert_file "lib/bukkits/engine.rb", /module Bukkits\n  class Engine < ::Rails::Engine\n  end\nend/
    assert_file "lib/bukkits.rb", /require "bukkits\/engine"/
  end

  def test_being_quiet_while_creating_dummy_application
    assert_no_match(/create\s+config\/application.rb/, run_generator)
  end

  def test_create_mountable_application_with_mountable_option
    run_generator [destination_root, "--mountable"]
    assert_file "app/assets/javascripts/bukkits"
    assert_file "app/assets/stylesheets/bukkits"
    assert_file "app/assets/images/bukkits"
    assert_file "config/routes.rb", /Bukkits::Engine.routes.draw do/
    assert_file "lib/bukkits/engine.rb", /isolate_namespace Bukkits/
    assert_file "test/dummy/config/routes.rb", /mount Bukkits::Engine => "\/bukkits"/
    assert_file "app/controllers/bukkits/application_controller.rb", /module Bukkits\n  class ApplicationController < ActionController::Base/
    assert_file "app/helpers/bukkits/application_helper.rb", /module Bukkits\n  module ApplicationHelper/
    assert_file "app/views/layouts/bukkits/application.html.erb" do |contents|
      assert_match "<title>Bukkits</title>", contents
      assert_match(/stylesheet_link_tag\s+['"]bukkits\/application['"]/, contents)
      assert_match(/javascript_include_tag\s+['"]bukkits\/application['"]/, contents)
    end
    assert_file "test/test_helper.rb" do |content|
      assert_match(/ActiveRecord::Migrator\.migrations_paths.+\.\.\/test\/dummy\/db\/migrate/, content)
      assert_match(/ActiveRecord::Migrator\.migrations_paths.+<<.+\.\.\/db\/migrate/, content)
    end
  end

  def test_creating_gemspec
    run_generator
    assert_file "bukkits.gemspec", /s.name\s+= "bukkits"/
    assert_file "bukkits.gemspec", /s.files = Dir\["\{app,config,db,lib\}\/\*\*\/\*", "MIT-LICENSE", "Rakefile", "README\.rdoc"\]/
    assert_file "bukkits.gemspec", /s.test_files = Dir\["test\/\*\*\/\*"\]/
    assert_file "bukkits.gemspec", /s.version\s+ = Bukkits::VERSION/
  end

  def test_usage_of_engine_commands
    run_generator [destination_root, "--full"]
    assert_file "bin/rails", /ENGINE_PATH = File.expand_path\('..\/..\/lib\/bukkits\/engine', __FILE__\)/
    assert_file "bin/rails", /ENGINE_ROOT = File.expand_path\('..\/..', __FILE__\)/
    assert_file "bin/rails", /require 'rails\/all'/
    assert_file "bin/rails", /require 'rails\/engine\/commands'/
  end

  def test_shebang
    run_generator [destination_root, "--full"]
    assert_file "bin/rails", /#!\/usr\/bin\/env ruby/
  end

  def test_passing_dummy_path_as_a_parameter
    run_generator [destination_root, "--dummy_path", "spec/dummy"]
    assert_file "spec/dummy"
    assert_file "spec/dummy/config/application.rb"
    assert_no_file "test/dummy"
    assert_file "test/test_helper.rb" do |content|
      assert_match(/require.+spec\/dummy\/config\/environment/, content)
      assert_match(/ActiveRecord::Migrator\.migrations_paths.+spec\/dummy\/db\/migrate/, content)
    end
  end

  def test_creating_dummy_application_with_different_name
    run_generator [destination_root, "--dummy_path", "spec/fake"]
    assert_file "spec/fake"
    assert_file "spec/fake/config/application.rb"
    assert_no_file "test/dummy"
    assert_file "test/test_helper.rb" do |content|
      assert_match(/require.+spec\/fake\/config\/environment/, content)
      assert_match(/ActiveRecord::Migrator\.migrations_paths.+spec\/fake\/db\/migrate/, content)
    end
  end

  def test_creating_dummy_without_tests_but_with_dummy_path
    run_generator [destination_root, "--dummy_path", "spec/dummy", "--skip-test-unit"]
    assert_file "spec/dummy"
    assert_file "spec/dummy/config/application.rb"
    assert_no_file "test"
    assert_no_file "test/test_helper.rb"
    assert_file '.gitignore' do |contents|
      assert_match(/spec\/dummy/, contents)
    end
  end

  def test_ensure_that_gitignore_can_be_generated_from_a_template_for_dummy_path
    FileUtils.cd(Rails.root)
    run_generator([destination_root, "--dummy_path", "spec/dummy", "--skip-test-unit"])
    assert_file ".gitignore" do |contents|
      assert_match(/spec\/dummy/, contents)
    end
  end

  def test_skipping_test_unit
    run_generator [destination_root, "--skip-test-unit"]
    assert_no_file "test"
    assert_file "bukkits.gemspec" do |contents|
      assert_no_match(/s.test_files = Dir\["test\/\*\*\/\*"\]/, contents)
    end
    assert_file '.gitignore' do |contents|
      assert_no_match(/test\dummy/, contents)
    end
  end

  def test_skipping_gemspec
    run_generator [destination_root, "--skip-gemspec"]
    assert_no_file "bukkits.gemspec"
    assert_file "Gemfile" do |contents|
      assert_no_match('gemspec', contents)
      assert_match(/gem "rails", "~> #{Rails.version}"/, contents)
      assert_match_sqlite3(contents)
      assert_no_match(/# gem "jquery-rails"/, contents)
    end
  end

  def test_skipping_gemspec_in_full_mode
    run_generator [destination_root, "--skip-gemspec", "--full"]
    assert_no_file "bukkits.gemspec"
    assert_file "Gemfile" do |contents|
      assert_no_match('gemspec', contents)
      assert_match(/gem "rails", "~> #{Rails.version}"/, contents)
      assert_match_sqlite3(contents)
    end
  end

  def test_creating_plugin_in_app_directory_adds_gemfile_entry
    # simulate application existence
    gemfile_path = "#{Rails.root}/Gemfile"
    Object.const_set('APP_PATH', Rails.root)
    FileUtils.touch gemfile_path

    run_generator [destination_root]

    assert_file gemfile_path, /gem 'bukkits', path: 'tmp\/bukkits'/
  ensure
    Object.send(:remove_const, 'APP_PATH')
    FileUtils.rm gemfile_path
  end

  def test_skipping_gemfile_entry
    # simulate application existence
    gemfile_path = "#{Rails.root}/Gemfile"
    Object.const_set('APP_PATH', Rails.root)
    FileUtils.touch gemfile_path

    run_generator [destination_root, "--skip-gemfile-entry"]

    assert_file gemfile_path do |contents|
      assert_no_match(/gem 'bukkits', path: 'tmp\/bukkits'/, contents)
    end
  ensure
    Object.send(:remove_const, 'APP_PATH')
    FileUtils.rm gemfile_path
  end

  def test_generating_controller_inside_mountable_engine
    run_generator [destination_root, "--mountable"]

    capture(:stdout) do
      `#{destination_root}/bin/rails g controller admin/dashboard foo`
    end

    assert_file "config/routes.rb" do |contents|
      assert_match(/namespace :admin/, contents)
      assert_no_match(/namespace :bukkit/, contents)
    end
  end

protected
  def action(*args, &block)
    silence(:stdout){ generator.send(*args, &block) }
  end

  def default_files
    ::DEFAULT_PLUGIN_FILES
  end

  def assert_match_sqlite3(contents)
    unless defined?(JRUBY_VERSION)
      assert_match(/group :development do\n  gem "sqlite3"\nend/, contents)
    else
      assert_match(/group :development do\n  gem "activerecord-jdbcsqlite3-adapter"\nend/, contents)
    end
  end
end
