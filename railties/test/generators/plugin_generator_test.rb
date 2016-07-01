require 'generators/generators_test_helper'
require 'rails/generators/rails/plugin/plugin_generator'
require 'generators/shared_generator_tests'

DEFAULT_PLUGIN_FILES = %w(
  .gitignore
  Gemfile
  Rakefile
  README.md
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
    content = capture(:stderr){ run_generator [File.join(destination_root, "my_plugin-31fr-extension")] }
    assert_equal "Invalid plugin name my_plugin-31fr-extension. Please give a name which does not contain a namespace starting with numeric characters.\n", content

    content = capture(:stderr){ run_generator [File.join(destination_root, "things4.3")] }
    assert_equal "Invalid plugin name things4.3. Please give a name which uses only alphabetic, numeric, \"_\" or \"-\" characters.\n", content

    content = capture(:stderr){ run_generator [File.join(destination_root, "43things")] }
    assert_equal "Invalid plugin name 43things. Please give a name which does not start with numbers.\n", content

    content = capture(:stderr){ run_generator [File.join(destination_root, "plugin")] }
    assert_equal "Invalid plugin name plugin. Please give a name which does not match one of the reserved rails words: application, destroy, plugin, runner, test\n", content

    content = capture(:stderr){ run_generator [File.join(destination_root, "Digest")] }
    assert_equal "Invalid plugin name Digest, constant Digest is already in use. Please choose another plugin name.\n", content
  end

  def test_correct_file_in_lib_folder_of_hyphenated_plugin_name
    run_generator [File.join(destination_root, "hyphenated-name")]
    assert_no_file "hyphenated-name/lib/hyphenated-name.rb"
    assert_no_file "hyphenated-name/lib/hyphenated_name.rb"
    assert_file "hyphenated-name/lib/hyphenated/name.rb", /module Hyphenated\n  module Name\n    # Your code goes here...\n  end\nend/
  end

  def test_correct_file_in_lib_folder_of_camelcase_plugin_name
    run_generator [File.join(destination_root, "CamelCasedName")]
    assert_no_file "CamelCasedName/lib/CamelCasedName.rb"
    assert_file "CamelCasedName/lib/camel_cased_name.rb", /module CamelCasedName/
  end

  def test_generating_without_options
    run_generator
    assert_file "README.md", /Bukkits/
    assert_no_file "config/routes.rb"
    assert_no_file "app/assets/config/bukkits_manifest.js"
    assert_file "test/test_helper.rb" do |content|
      assert_match(/require.+test\/dummy\/config\/environment/, content)
      assert_match(/ActiveRecord::Migrator\.migrations_paths.+test\/dummy\/db\/migrate/, content)
      assert_match(/Minitest\.backtrace_filter = Minitest::BacktraceFilter\.new/, content)
      assert_match(/Rails::TestUnitReporter\.executable = 'bin\/test'/, content)
    end
    assert_file "test/bukkits_test.rb", /assert_kind_of Module, Bukkits/
    assert_file 'bin/test'
    assert_no_file 'bin/rails'
  end

  def test_generating_test_files_in_full_mode
    run_generator [destination_root, "--full"]
    assert_directory "test/integration/"

    assert_file "test/integration/navigation_test.rb", /ActionDispatch::IntegrationTest/
  end

  def test_inclusion_of_a_debugger
    run_generator [destination_root, '--full']
    if defined?(JRUBY_VERSION) || RUBY_ENGINE == "rbx"
      assert_file "Gemfile" do |content|
        assert_no_match(/byebug/, content)
      end
    else
      assert_file "Gemfile", /# gem 'byebug'/
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
    run_generator

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
    run_generator([destination_root, "-m", "lib/create_test_dummy_template.rb", "--skip-test"])
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

  def test_app_generator_without_skips
    run_generator
    assert_file "test/dummy/config/application.rb", /\s+require\s+["']rails\/all["']/
    assert_file "test/dummy/config/environments/development.rb" do |content|
      assert_match(/config\.action_mailer\.raise_delivery_errors = false/, content)
    end
    assert_file "test/dummy/config/environments/test.rb" do |content|
      assert_match(/config\.action_mailer\.delivery_method = :test/, content)
    end
    assert_file "test/dummy/config/environments/production.rb" do |content|
      assert_match(/# config\.action_mailer\.raise_delivery_errors = false/, content)
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

  def test_action_mailer_is_removed_from_frameworks_if_skip_action_mailer_is_given
    run_generator [destination_root, "--skip-action-mailer"]
    assert_file "test/dummy/config/application.rb", /#\s+require\s+["']action_mailer\/railtie["']/
    assert_file "test/dummy/config/environments/development.rb" do |content|
      assert_no_match(/config\.action_mailer/, content)
    end
    assert_file "test/dummy/config/environments/test.rb" do |content|
      assert_no_match(/config\.action_mailer/, content)
    end
    assert_file "test/dummy/config/environments/production.rb" do |content|
      assert_no_match(/config\.action_mailer/, content)
    end
  end

  def test_ensure_that_database_option_is_passed_to_app_generator
    run_generator [destination_root, "--database", "postgresql"]
    assert_file "test/dummy/config/database.yml", /postgres/
  end

  def test_generation_runs_bundle_install
    assert_generates_without_bundler
  end

  def test_dev_option
    assert_generates_without_bundler(dev: true)
    rails_path = File.expand_path('../../..', Rails.root)
    assert_file 'Gemfile', /^gem\s+["']rails["'],\s+path:\s+["']#{Regexp.escape(rails_path)}["']$/
  end

  def test_edge_option
    assert_generates_without_bundler(edge: true)
    assert_file 'Gemfile', %r{^gem\s+["']rails["'],\s+github:\s+["']#{Regexp.escape("rails/rails")}["'],\s+branch:\s+["']#{Regexp.escape("5-0-stable")}["']$}
  end

  def test_generation_does_not_run_bundle_install_with_full_and_mountable
    assert_generates_without_bundler(mountable: true, full: true, dev: true)
    assert_no_file "#{destination_root}/Gemfile.lock"
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
    assert_match(/1 runs, 1 assertions, 0 failures, 0 errors/, `bin/test 2>&1`)
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
    output = `bin/rails db:migrate 2>&1`
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

  def test_creating_engine_with_hyphenated_name_in_full_mode
    run_generator [File.join(destination_root, "hyphenated-name"), "--full"]
    assert_file "hyphenated-name/app/assets/javascripts/hyphenated/name"
    assert_file "hyphenated-name/app/assets/stylesheets/hyphenated/name"
    assert_file "hyphenated-name/app/assets/images/hyphenated/name"
    assert_file "hyphenated-name/app/models"
    assert_file "hyphenated-name/app/controllers"
    assert_file "hyphenated-name/app/views"
    assert_file "hyphenated-name/app/helpers"
    assert_file "hyphenated-name/app/mailers"
    assert_file "hyphenated-name/bin/rails"
    assert_file "hyphenated-name/config/routes.rb",              /Rails.application.routes.draw do/
    assert_file "hyphenated-name/lib/hyphenated/name/engine.rb", /module Hyphenated\n  module Name\n    class Engine < ::Rails::Engine\n    end\n  end\nend/
    assert_file "hyphenated-name/lib/hyphenated/name.rb",        /require "hyphenated\/name\/engine"/
    assert_file "hyphenated-name/bin/rails",                     /\.\.\/\.\.\/lib\/hyphenated\/name\/engine/
  end

  def test_creating_engine_with_hyphenated_and_underscored_name_in_full_mode
    run_generator [File.join(destination_root, "my_hyphenated-name"), "--full"]
    assert_file "my_hyphenated-name/app/assets/javascripts/my_hyphenated/name"
    assert_file "my_hyphenated-name/app/assets/stylesheets/my_hyphenated/name"
    assert_file "my_hyphenated-name/app/assets/images/my_hyphenated/name"
    assert_file "my_hyphenated-name/app/models"
    assert_file "my_hyphenated-name/app/controllers"
    assert_file "my_hyphenated-name/app/views"
    assert_file "my_hyphenated-name/app/helpers"
    assert_file "my_hyphenated-name/app/mailers"
    assert_file "my_hyphenated-name/bin/rails"
    assert_file "my_hyphenated-name/config/routes.rb",              /Rails.application.routes.draw do/
    assert_file "my_hyphenated-name/lib/my_hyphenated/name/engine.rb", /module MyHyphenated\n  module Name\n    class Engine < ::Rails::Engine\n    end\n  end\nend/
    assert_file "my_hyphenated-name/lib/my_hyphenated/name.rb",        /require "my_hyphenated\/name\/engine"/
    assert_file "my_hyphenated-name/bin/rails",                     /\.\.\/\.\.\/lib\/my_hyphenated\/name\/engine/
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
    assert_file "app/models/bukkits/application_record.rb", /module Bukkits\n  class ApplicationRecord < ActiveRecord::Base/
    assert_file "app/jobs/bukkits/application_job.rb", /module Bukkits\n  class ApplicationJob < ActiveJob::Base/
    assert_file "app/mailers/bukkits/application_mailer.rb", /module Bukkits\n  class ApplicationMailer < ActionMailer::Base\n    default from: 'from@example.com'\n    layout 'mailer'\n/
    assert_file "app/helpers/bukkits/application_helper.rb", /module Bukkits\n  module ApplicationHelper/
    assert_file "app/views/layouts/bukkits/application.html.erb" do |contents|
      assert_match "<title>Bukkits</title>", contents
      assert_match(/stylesheet_link_tag\s+['"]bukkits\/application['"]/, contents)
      assert_match(/javascript_include_tag\s+['"]bukkits\/application['"]/, contents)
    end
    assert_file "test/test_helper.rb" do |content|
      assert_match(/ActiveRecord::Migrator\.migrations_paths.+\.\.\/test\/dummy\/db\/migrate/, content)
      assert_match(/ActiveRecord::Migrator\.migrations_paths.+<<.+\.\.\/db\/migrate/, content)
      assert_match(/ActionDispatch::IntegrationTest\.fixture_path = ActiveSupport::TestCase\.fixture_pat/, content)
      assert_no_match(/Rails::TestUnitReporter\.executable = 'bin\/test'/, content)
    end
    assert_no_file 'bin/test'
  end

  def test_create_mountable_application_with_mountable_option_and_hypenated_name
    run_generator [File.join(destination_root, "hyphenated-name"), "--mountable"]
    assert_file "hyphenated-name/app/assets/javascripts/hyphenated/name"
    assert_file "hyphenated-name/app/assets/stylesheets/hyphenated/name"
    assert_file "hyphenated-name/app/assets/images/hyphenated/name"
    assert_file "hyphenated-name/config/routes.rb",                                          /Hyphenated::Name::Engine.routes.draw do/
    assert_file "hyphenated-name/lib/hyphenated/name/version.rb",                            /module Hyphenated\n  module Name\n    VERSION = '0.1.0'\n  end\nend/
    assert_file "hyphenated-name/lib/hyphenated/name/engine.rb",                             /module Hyphenated\n  module Name\n    class Engine < ::Rails::Engine\n      isolate_namespace Hyphenated::Name\n    end\n  end\nend/
    assert_file "hyphenated-name/lib/hyphenated/name.rb",                                    /require "hyphenated\/name\/engine"/
    assert_file "hyphenated-name/test/dummy/config/routes.rb",                               /mount Hyphenated::Name::Engine => "\/hyphenated-name"/
    assert_file "hyphenated-name/app/controllers/hyphenated/name/application_controller.rb", /module Hyphenated\n  module Name\n    class ApplicationController < ActionController::Base\n      protect_from_forgery with: :exception\n    end\n  end\nend\n/
    assert_file "hyphenated-name/app/models/hyphenated/name/application_record.rb",          /module Hyphenated\n  module Name\n    class ApplicationRecord < ActiveRecord::Base\n      self\.abstract_class = true\n    end\n  end\nend/
    assert_file "hyphenated-name/app/jobs/hyphenated/name/application_job.rb",               /module Hyphenated\n  module Name\n    class ApplicationJob < ActiveJob::Base/
    assert_file "hyphenated-name/app/mailers/hyphenated/name/application_mailer.rb",         /module Hyphenated\n  module Name\n    class ApplicationMailer < ActionMailer::Base\n      default from: 'from@example.com'\n      layout 'mailer'\n    end\n  end\nend/
    assert_file "hyphenated-name/app/helpers/hyphenated/name/application_helper.rb",         /module Hyphenated\n  module Name\n    module ApplicationHelper\n    end\n  end\nend/
    assert_file "hyphenated-name/app/views/layouts/hyphenated/name/application.html.erb" do |contents|
      assert_match "<title>Hyphenated name</title>", contents
      assert_match(/stylesheet_link_tag\s+['"]hyphenated\/name\/application['"]/, contents)
      assert_match(/javascript_include_tag\s+['"]hyphenated\/name\/application['"]/, contents)
    end
  end

  def test_create_mountable_application_with_mountable_option_and_hypenated_and_underscored_name
    run_generator [File.join(destination_root, "my_hyphenated-name"), "--mountable"]
    assert_file "my_hyphenated-name/app/assets/javascripts/my_hyphenated/name"
    assert_file "my_hyphenated-name/app/assets/stylesheets/my_hyphenated/name"
    assert_file "my_hyphenated-name/app/assets/images/my_hyphenated/name"
    assert_file "my_hyphenated-name/config/routes.rb",                                             /MyHyphenated::Name::Engine.routes.draw do/
    assert_file "my_hyphenated-name/lib/my_hyphenated/name/version.rb",                            /module MyHyphenated\n  module Name\n    VERSION = '0.1.0'\n  end\nend/
    assert_file "my_hyphenated-name/lib/my_hyphenated/name/engine.rb",                             /module MyHyphenated\n  module Name\n    class Engine < ::Rails::Engine\n      isolate_namespace MyHyphenated::Name\n    end\n  end\nend/
    assert_file "my_hyphenated-name/lib/my_hyphenated/name.rb",                                    /require "my_hyphenated\/name\/engine"/
    assert_file "my_hyphenated-name/test/dummy/config/routes.rb",                                  /mount MyHyphenated::Name::Engine => "\/my_hyphenated-name"/
    assert_file "my_hyphenated-name/app/controllers/my_hyphenated/name/application_controller.rb", /module MyHyphenated\n  module Name\n    class ApplicationController < ActionController::Base\n      protect_from_forgery with: :exception\n    end\n  end\nend\n/
    assert_file "my_hyphenated-name/app/models/my_hyphenated/name/application_record.rb",          /module MyHyphenated\n  module Name\n    class ApplicationRecord < ActiveRecord::Base\n      self\.abstract_class = true\n    end\n  end\nend/
    assert_file "my_hyphenated-name/app/jobs/my_hyphenated/name/application_job.rb",               /module MyHyphenated\n  module Name\n    class ApplicationJob < ActiveJob::Base/
    assert_file "my_hyphenated-name/app/mailers/my_hyphenated/name/application_mailer.rb",         /module MyHyphenated\n  module Name\n    class ApplicationMailer < ActionMailer::Base\n      default from: 'from@example.com'\n      layout 'mailer'\n    end\n  end\nend/
    assert_file "my_hyphenated-name/app/helpers/my_hyphenated/name/application_helper.rb",         /module MyHyphenated\n  module Name\n    module ApplicationHelper\n    end\n  end\nend/
    assert_file "my_hyphenated-name/app/views/layouts/my_hyphenated/name/application.html.erb" do |contents|
      assert_match "<title>My hyphenated name</title>", contents
      assert_match(/stylesheet_link_tag\s+['"]my_hyphenated\/name\/application['"]/, contents)
      assert_match(/javascript_include_tag\s+['"]my_hyphenated\/name\/application['"]/, contents)
    end
  end

  def test_create_mountable_application_with_mountable_option_and_multiple_hypenates_in_name
    run_generator [File.join(destination_root, "deep-hyphenated-name"), "--mountable"]
    assert_file "deep-hyphenated-name/app/assets/javascripts/deep/hyphenated/name"
    assert_file "deep-hyphenated-name/app/assets/stylesheets/deep/hyphenated/name"
    assert_file "deep-hyphenated-name/app/assets/images/deep/hyphenated/name"
    assert_file "deep-hyphenated-name/config/routes.rb",                                               /Deep::Hyphenated::Name::Engine.routes.draw do/
    assert_file "deep-hyphenated-name/lib/deep/hyphenated/name/version.rb",                            /module Deep\n  module Hyphenated\n    module Name\n      VERSION = '0.1.0'\n    end\n  end\nend/
    assert_file "deep-hyphenated-name/lib/deep/hyphenated/name/engine.rb",                             /module Deep\n  module Hyphenated\n    module Name\n      class Engine < ::Rails::Engine\n        isolate_namespace Deep::Hyphenated::Name\n      end\n    end\n  end\nend/
    assert_file "deep-hyphenated-name/lib/deep/hyphenated/name.rb",                                    /require "deep\/hyphenated\/name\/engine"/
    assert_file "deep-hyphenated-name/test/dummy/config/routes.rb",                                    /mount Deep::Hyphenated::Name::Engine => "\/deep-hyphenated-name"/
    assert_file "deep-hyphenated-name/app/controllers/deep/hyphenated/name/application_controller.rb", /module Deep\n  module Hyphenated\n    module Name\n      class ApplicationController < ActionController::Base\n        protect_from_forgery with: :exception\n      end\n    end\n  end\nend\n/
    assert_file "deep-hyphenated-name/app/models/deep/hyphenated/name/application_record.rb",          /module Deep\n  module Hyphenated\n    module Name\n      class ApplicationRecord < ActiveRecord::Base\n        self\.abstract_class = true\n      end\n    end\n  end\nend/
    assert_file "deep-hyphenated-name/app/jobs/deep/hyphenated/name/application_job.rb",               /module Deep\n  module Hyphenated\n    module Name\n      class ApplicationJob < ActiveJob::Base/
    assert_file "deep-hyphenated-name/app/mailers/deep/hyphenated/name/application_mailer.rb",         /module Deep\n  module Hyphenated\n    module Name\n      class ApplicationMailer < ActionMailer::Base\n        default from: 'from@example.com'\n        layout 'mailer'\n      end\n    end\n  end\nend/
    assert_file "deep-hyphenated-name/app/helpers/deep/hyphenated/name/application_helper.rb",         /module Deep\n  module Hyphenated\n    module Name\n      module ApplicationHelper\n      end\n    end\n  end\nend/
    assert_file "deep-hyphenated-name/app/views/layouts/deep/hyphenated/name/application.html.erb" do |contents|
      assert_match "<title>Deep hyphenated name</title>", contents
      assert_match(/stylesheet_link_tag\s+['"]deep\/hyphenated\/name\/application['"]/, contents)
      assert_match(/javascript_include_tag\s+['"]deep\/hyphenated\/name\/application['"]/, contents)
    end
  end

  def test_creating_gemspec
    run_generator
    assert_file "bukkits.gemspec", /s.name\s+= "bukkits"/
    assert_file "bukkits.gemspec", /s.files = Dir\["\{app,config,db,lib\}\/\*\*\/\*", "MIT-LICENSE", "Rakefile", "README\.md"\]/
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
    run_generator [destination_root, "--dummy_path", "spec/dummy", "--skip-test"]
    assert_file "spec/dummy"
    assert_file "spec/dummy/config/application.rb"
    assert_no_file "test"
    assert_no_file "test/test_helper.rb"
    assert_file '.gitignore' do |contents|
      assert_match(/spec\/dummy/, contents)
    end
  end

  def test_dummy_appplication_skip_listen_by_default
    run_generator

    assert_file 'test/dummy/config/environments/development.rb' do |contents|
      assert_match(/^\s*# config.file_watcher = ActiveSupport::EventedFileUpdateChecker/, contents)
    end
  end

  def test_ensure_that_gitignore_can_be_generated_from_a_template_for_dummy_path
    FileUtils.cd(Rails.root)
    run_generator([destination_root, "--dummy_path", "spec/dummy", "--skip-test"])
    assert_file ".gitignore" do |contents|
      assert_match(/spec\/dummy/, contents)
    end
  end

  def test_unnecessary_files_are_not_generated_in_dummy_application
    run_generator
    assert_no_file 'test/dummy/.gitignore'
    assert_no_file 'test/dummy/db/seeds.rb'
    assert_no_file 'test/dummy/Gemfile'
    assert_no_file 'test/dummy/public/robots.txt'
    assert_no_file 'test/dummy/README.md'
    assert_no_directory 'test/dummy/lib/tasks'
    assert_no_directory 'test/dummy/doc'
    assert_no_directory 'test/dummy/test'
    assert_no_directory 'test/dummy/vendor'
  end

  def test_skipping_test_files
    run_generator [destination_root, "--skip-test"]
    assert_no_file "test"
    assert_file '.gitignore' do |contents|
      assert_no_match(/test\dummy/, contents)
    end
  end

  def test_skipping_gemspec
    run_generator [destination_root, "--skip-gemspec"]
    assert_no_file "bukkits.gemspec"
    assert_file "Gemfile" do |contents|
      assert_no_match('gemspec', contents)
      assert_match(/gem 'rails'/, contents)
      assert_match_sqlite3(contents)
      assert_no_match(/# gem "jquery-rails"/, contents)
    end
  end

  def test_skipping_gemspec_in_full_mode
    run_generator [destination_root, "--skip-gemspec", "--full"]
    assert_no_file "bukkits.gemspec"
    assert_file "Gemfile" do |contents|
      assert_no_match('gemspec', contents)
      assert_match(/gem 'rails'/, contents)
      assert_match_sqlite3(contents)
    end
  end

  def test_creating_plugin_in_app_directory_adds_gemfile_entry
    # simulate application existence
    gemfile_path = "#{Rails.root}/Gemfile"
    Object.const_set('APP_PATH', Rails.root)
    FileUtils.touch gemfile_path

    run_generator

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

  def test_git_name_and_email_in_gemspec_file
    name = `git config user.name`.chomp rescue "TODO: Write your name"
    email = `git config user.email`.chomp rescue "TODO: Write your email address"

    run_generator
    assert_file "bukkits.gemspec" do |contents|
      assert_match name, contents
      assert_match email, contents
    end
  end

  def test_git_name_in_license_file
    name = `git config user.name`.chomp rescue "TODO: Write your name"

    run_generator
    assert_file "MIT-LICENSE" do |contents|
      assert_match name, contents
    end
  end

  def test_no_details_from_git_when_skip_git
    name = "TODO: Write your name"
    email = "TODO: Write your email address"

    run_generator [destination_root, '--skip-git']
    assert_file "MIT-LICENSE" do |contents|
      assert_match name, contents
    end
    assert_file "bukkits.gemspec" do |contents|
      assert_match name, contents
      assert_match email, contents
    end
  end

  def test_skipping_useless_folders_generation_for_api_engines
    ['--full', '--mountable'].each do |option|
      run_generator [destination_root, option, '--api']

      assert_no_directory "app/assets"
      assert_no_directory "app/helpers"
      assert_no_directory "app/views"

      FileUtils.rm_rf destination_root
    end
  end

  def test_application_controller_parent_for_mountable_api_plugins
    run_generator [destination_root, '--mountable', '--api']

    assert_file "app/controllers/bukkits/application_controller.rb" do |content|
      assert_match "ApplicationController < ActionController::API", content
    end
  end

  def test_dummy_api_application_for_api_plugins
    run_generator [destination_root, '--api']

    assert_file "test/dummy/config/application.rb" do |content|
      assert_match "config.api_only = true", content
    end
  end


  def test_api_generators_configuration_for_api_engines
    run_generator [destination_root, '--full', '--api']

    assert_file "lib/bukkits/engine.rb" do |content|
      assert_match "config.generators.api_only = true", content
    end
  end

  def test_scaffold_generator_for_mountable_api_plugins
    run_generator [destination_root, '--mountable', '--api']

    capture(:stdout) do
      `#{destination_root}/bin/rails g scaffold article`
    end

    assert_file "app/models/bukkits/article.rb"
    assert_file "app/controllers/bukkits/articles_controller.rb" do |content|
      assert_match "only: [:show, :update, :destroy]", content
    end

    assert_no_directory "app/assets"
    assert_no_directory "app/helpers"
    assert_no_directory "app/views"
  end

  def test_model_with_existent_application_record_in_mountable_engine
    run_generator [destination_root, '--mountable']
    capture(:stdout) do
      `#{destination_root}/bin/rails g model article`
    end

    assert_file "app/models/bukkits/article.rb", /class Article < ApplicationRecord/
  end

  def test_generate_application_record_when_does_not_exist_in_mountable_engine
    run_generator [destination_root, '--mountable']
    FileUtils.rm "#{destination_root}/app/models/bukkits/application_record.rb"
    capture(:stdout) do
      `#{destination_root}/bin/rails g model article`
    end

    assert_file "#{destination_root}/app/models/bukkits/application_record.rb" do |record|
      assert_match(/module Bukkits/, record)
      assert_match(/class ApplicationRecord < ActiveRecord::Base/, record)
      assert_match(/self.abstract_class = true/, record)
    end
  end

  def test_generate_application_mailer_when_does_not_exist_in_mountable_engine
    run_generator [destination_root, '--mountable']
    FileUtils.rm "#{destination_root}/app/mailers/bukkits/application_mailer.rb"
    capture(:stdout) do
      `#{destination_root}/bin/rails g mailer User`
    end

    assert_file "#{destination_root}/app/mailers/bukkits/application_mailer.rb" do |mailer|
      assert_match(/module Bukkits/, mailer)
      assert_match(/class ApplicationMailer < ActionMailer::Base/, mailer)
    end
  end

  def test_generate_mailer_layouts_when_does_not_exist_in_mountable_engine
    run_generator [destination_root, '--mountable']
    capture(:stdout) do
      `#{destination_root}/bin/rails g mailer User`
    end

    assert_file "#{destination_root}/app/views/layouts/bukkits/mailer.text.erb" do |view|
      assert_match(/<%= yield %>/, view)
    end

    assert_file "#{destination_root}/app/views/layouts/bukkits/mailer.html.erb" do |view|
      assert_match(%r{<body>\n    <%= yield %>\n  </body>}, view)
    end
  end

  def test_generate_application_job_when_does_not_exist_in_mountable_engine
    run_generator [destination_root, '--mountable']
    FileUtils.rm "#{destination_root}/app/jobs/bukkits/application_job.rb"
    capture(:stdout) do
      `#{destination_root}/bin/rails g job refresh_counters`
    end

    assert_file "#{destination_root}/app/jobs/bukkits/application_job.rb" do |record|
      assert_match(/module Bukkits/, record)
      assert_match(/class ApplicationJob < ActiveJob::Base/, record)
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
      if defined?(JRUBY_VERSION)
        assert_match(/group :development do\n  gem 'activerecord-jdbcsqlite3-adapter'\nend/, contents)
      else
        assert_match(/group :development do\n  gem 'sqlite3'\nend/, contents)
      end
    end

    def assert_generates_without_bundler(options = {})
      generator([destination_root], options)

      command_check = -> command do
        case command
        when 'install'
          flunk "install expected to not be called"
        when 'exec spring binstub --all'
          # Called when running tests with spring, let through unscathed.
        end
      end

      generator.stub :bundle_command, command_check do
        quietly { generator.invoke_all }
      end
    end
end
