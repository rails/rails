# frozen_string_literal: true

require "plugin_helpers"
require "generators/generators_test_helper"
require "rails/generators/rails/plugin/plugin_generator"
require "generators/shared_generator_tests"
require "rails/engine/updater"

DEFAULT_PLUGIN_FILES = %w(
  .git
  .github/dependabot.yml
  .github/workflows/ci.yml
  .gitignore
  .rubocop.yml
  Gemfile
  MIT-LICENSE
  README.md
  Rakefile
  bin/rubocop
  bin/test
  bukkits.gemspec
  lib/bukkits.rb
  lib/bukkits/railtie.rb
  lib/bukkits/version.rb
  lib/tasks/bukkits_tasks.rake
  test/bukkits_test.rb
  test/dummy/Rakefile
  test/dummy/app/assets/images/.keep
  test/dummy/app/assets/stylesheets/application.css
  test/dummy/app/controllers/application_controller.rb
  test/dummy/app/controllers/concerns/.keep
  test/dummy/app/helpers/application_helper.rb
  test/dummy/app/jobs/application_job.rb
  test/dummy/app/mailers/application_mailer.rb
  test/dummy/app/models/application_record.rb
  test/dummy/app/models/concerns/.keep
  test/dummy/app/views/layouts/application.html.erb
  test/dummy/app/views/layouts/mailer.html.erb
  test/dummy/app/views/layouts/mailer.text.erb
  test/dummy/app/views/pwa/manifest.json.erb
  test/dummy/app/views/pwa/service-worker.js
  test/dummy/bin/dev
  test/dummy/bin/rails
  test/dummy/bin/rake
  test/dummy/bin/setup
  test/dummy/config.ru
  test/dummy/config/application.rb
  test/dummy/config/boot.rb
  test/dummy/config/cable.yml
  test/dummy/config/database.yml
  test/dummy/config/environment.rb
  test/dummy/config/environments/development.rb
  test/dummy/config/environments/production.rb
  test/dummy/config/environments/test.rb
  test/dummy/config/initializers/content_security_policy.rb
  test/dummy/config/initializers/filter_parameter_logging.rb
  test/dummy/config/initializers/inflections.rb
  test/dummy/config/locales/en.yml
  test/dummy/config/puma.rb
  test/dummy/config/routes.rb
  test/dummy/config/storage.yml
  test/dummy/log/.keep
  test/dummy/public/400.html
  test/dummy/public/404.html
  test/dummy/public/406-unsupported-browser.html
  test/dummy/public/422.html
  test/dummy/public/500.html
  test/dummy/public/icon.png
  test/dummy/public/icon.svg
  test/dummy/storage/.keep
  test/dummy/tmp/.keep
  test/dummy/tmp/pids/.keep
  test/dummy/tmp/storage/.keep
  test/test_helper.rb
)

class PluginGeneratorTest < Rails::Generators::TestCase
  include PluginHelpers
  include GeneratorsTestHelper
  destination File.join(destination_root, "bukkits")
  arguments [destination_root]

  def application_path
    "#{destination_root}/test/dummy"
  end

  # brings setup, teardown, and some tests
  include SharedGeneratorTests

  def test_invalid_plugin_name_raises_an_error
    content = capture(:stderr) { run_generator [File.join(destination_root, "my_plugin-31fr-extension")] }
    assert_equal "Invalid plugin name my_plugin-31fr-extension. Please give a name which does not contain a namespace starting with numeric characters.\n", content

    content = capture(:stderr) { run_generator [File.join(destination_root, "things4.3")] }
    assert_equal "Invalid plugin name things4.3. Please give a name which uses only alphabetic, numeric, \"_\" or \"-\" characters.\n", content

    content = capture(:stderr) { run_generator [File.join(destination_root, "43things")] }
    assert_equal "Invalid plugin name 43things. Please give a name which does not start with numbers.\n", content

    content = capture(:stderr) { run_generator [File.join(destination_root, "plugin")] }
    assert_equal "Invalid plugin name plugin. Please give a name which does not match one of the reserved rails words: application, destroy, plugin, runner, test\n", content

    content = capture(:stderr) { run_generator [File.join(destination_root, "Digest")] }
    assert_equal "Invalid plugin name Digest, constant Digest is already in use. Please choose another plugin name.\n", content
  end

  def test_correct_file_in_lib_folder_of_hyphenated_plugin_name
    run_generator [File.join(destination_root, "hyphenated-name")]
    assert_no_file "hyphenated-name/lib/hyphenated-name.rb"
    assert_no_file "hyphenated-name/lib/hyphenated_name.rb"
    assert_file "hyphenated-name/lib/hyphenated/name.rb", /module Hyphenated\n  module Name\n    # Your code goes here\.\.\.\n  end\nend/
  end

  def test_correct_file_in_lib_folder_of_camelcase_plugin_name
    run_generator [File.join(destination_root, "CamelCasedName")]
    assert_no_file "CamelCasedName/lib/CamelCasedName.rb"
    assert_file "CamelCasedName/lib/camel_cased_name.rb", /module CamelCasedName/
  end

  def test_generating_without_options
    run_generator
    assert_file "README.md", /Bukkits/
    assert_file "test/test_helper.rb" do |content|
      assert_match(/require_relative.+test\/dummy\/config\/environment/, content)
      assert_match(/ActiveRecord::Migrator\.migrations_paths.+test\/dummy\/db\/migrate/, content)
    end
    assert_file "lib/bukkits/railtie.rb", /module Bukkits\n  class Railtie < ::Rails::Railtie\n  end\nend/
    assert_file "lib/bukkits.rb" do |content|
      assert_match(/require "bukkits\/version"/, content)
      assert_match(/require "bukkits\/railtie"/, content)
    end
    assert_file "test/bukkits_test.rb" do |content|
      assert_match(/class BukkitsTest < ActiveSupport::TestCase/, content)
      assert_match(/assert Bukkits::VERSION/, content)
    end
  end

  def test_initializes_git_repo_with_main_branch_without_user_default
    current_default_branch = `git config --global init.defaultBranch`
    `git config --global --unset init.defaultBranch`

    run_generator
    assert_file ".git/HEAD", /main/
  ensure
    if !current_default_branch.strip.empty?
      `git config --global init.defaultBranch #{current_default_branch}`
    end
  end

  def test_version_control_initializes_git_repo_with_user_default_branch
    git_version = `git --version`[/\d+.\d+.\d+/]
    return if Gem::Version.new(git_version) < Gem::Version.new("2.28.0")

    current_default_branch = `git config --global init.defaultBranch`
    `git config --global init.defaultBranch master`

    run_generator
    assert_file ".git/HEAD", /master/
  ensure
    if current_default_branch && current_default_branch.strip.empty?
      `git config --global --unset init.defaultBranch`
    elsif current_default_branch
      `git config --global init.defaultBranch #{current_default_branch}`
    end
  end

  def test_generating_in_full_mode_with_almost_of_all_skip_options
    run_generator [destination_root, "--full", "-M", "-O", "-C", "-T", "--skip-active-storage", "--skip-active-job"]
    assert_file "bin/rails" do |content|
      assert_no_match(/\s+require\s+["']rails\/all["']/, content)
    end
    assert_file "bin/rails", /#\s+require\s+["']active_job\/railtie["']/
    assert_file "bin/rails", /#\s+require\s+["']active_record\/railtie["']/
    assert_file "bin/rails", /#\s+require\s+["']active_storage\/engine["']/
    assert_file "bin/rails", /#\s+require\s+["']action_mailer\/railtie["']/
    assert_file "bin/rails", /#\s+require\s+["']action_cable\/engine["']/
    assert_file "bin/rails", /#\s+require\s+["']rails\/test_unit\/railtie["']/
  end

  def test_generating_test_files_in_full_mode
    run_generator [destination_root, "--full"]
    assert_directory "test/integration/"

    assert_file "test/integration/navigation_test.rb", /ActionDispatch::IntegrationTest/
  end

  def test_inclusion_of_a_debugger
    run_generator [destination_root, "--full"]
    if defined?(JRUBY_VERSION)
      assert_file "Gemfile" do |content|
        assert_no_match(/debug/, content)
      end
    else
      assert_file "Gemfile", /# gem "debug"/
    end
  end

  def test_generating_test_files_in_full_mode_without_unit_test_files
    run_generator [destination_root, "-T", "--full"]

    assert_no_directory "test/integration/"
    assert_no_directory "test"
    assert_file "Rakefile" do |contents|
      assert_no_match(/APP_RAKEFILE/, contents)
    end
    assert_file "bin/rails" do |contents|
      assert_no_match(/APP_PATH/, contents)
    end
  end

  def test_generating_adds_dummy_app_rake_tasks_without_unit_test_files
    run_generator [destination_root, "-T", "--mountable", "--dummy-path", "my_dummy_app"]
    assert_file "Rakefile", /APP_RAKEFILE/
    assert_file "bin/rails", /APP_PATH/
  end

  def test_ensure_that_plugin_options_are_not_passed_to_app_generator
    FileUtils.cd(fixtures_root)
    assert_no_match(/It works from file!.*It works_from_file/, run_generator([destination_root, "-m", "lib/template.rb"]))
  end

  def test_ensure_that_test_dummy_can_be_generated_from_a_template
    FileUtils.cd(fixtures_root)
    run_generator([destination_root, "-m", "lib/create_test_dummy_template.rb", "--skip-test"])
    assert_directory "spec/dummy"
    assert_no_directory "test"
  end

  def test_no_development_dependencies_in_gemspec
    run_generator
    assert_file "bukkits.gemspec" do |contents|
      assert_no_match(/add_development_dependency/, contents)
    end
  end

  def test_default_database_dependency_is_sqlite
    run_generator
    assert_file "test/dummy/config/database.yml", /sqlite/
    assert_gem "sqlite3"
  end

  def test_custom_database_dependency
    run_generator [destination_root, "-d", "mysql"]
    assert_file "test/dummy/config/database.yml", /mysql/
    assert_file "Gemfile", /mysql/
  end

  def test_ensure_that_skip_active_record_option_is_passed_to_app_generator
    run_generator [destination_root, "--skip_active_record"]
    assert_file "test/test_helper.rb" do |contents|
      assert_no_match(/ActiveRecord/, contents)
    end
  end

  def test_ensure_that_database_option_is_passed_to_app_generator
    run_generator [destination_root, "--database", "postgresql"]
    assert_file "test/dummy/config/database.yml", /postgres/
  end

  def test_no_duplicate_gemfile_entries_when_using_prerelease
    run_generator_using_prerelease [destination_root, "--dev"]

    assert_file "Gemfile" do |content|
      assert_equal 1, content.scan(/gem "sqlite3"/).length
    end
  end

  def test_generation_does_not_run_bundle_install
    generator([destination_root])
    run_generator_instance

    assert_empty @bundle_commands
  end

  def test_generation_does_not_run_bundle_install_with_full_and_mountable
    generator([destination_root], mountable: true, full: true)
    run_generator_instance

    assert_empty @bundle_commands
    assert_no_file "#{destination_root}/Gemfile.lock"
  end

  def test_skip_action_mailer_and_skip_active_job_with_mountable
    run_generator [destination_root, "--mountable", "--skip-action-mailer", "--skip-active-job"]
    assert_no_directory "app/mailers"
    assert_no_directory "app/jobs"
  end

  def test_skip_action_mailer_and_skip_active_job_with_api_and_mountable
    run_generator [destination_root, "--api", "--mountable", "--skip-action-mailer", "--skip-active-job"]
    assert_no_directory "app/mailers"
    assert_no_directory "app/jobs"
  end

  def test_skip_action_mailer_and_skip_active_job_with_full
    run_generator [destination_root, "--full", "--skip-action-mailer", "--skip-active-job"]
    assert_no_directory "app/mailers"
    assert_no_directory "app/jobs"
  end

  def test_ensure_that_migration_tasks_work_with_mountable_option
    run_generator [destination_root, "--mountable"]
    prepare_plugin(destination_root)

    in_plugin_context(destination_root) do
      quietly { system "bundle install" }
      output = `bin/rails db:migrate 2>&1`
      assert_predicate $?, :success?, "Command failed: #{output}"
    end
  end

  def test_creating_engine_in_full_mode
    run_generator [destination_root, "--full"]
    assert_file "app/assets/stylesheets/bukkits"
    assert_file "app/assets/images/bukkits"
    assert_file "app/models"
    assert_file "app/controllers"
    assert_file "app/views"
    assert_file "app/helpers"
    assert_file "app/mailers"
    assert_file "app/jobs"
    assert_file "bin/rails", /\s+require\s+["']rails\/all["']/
    assert_file "config/routes.rb", /Rails.application.routes.draw do/
    assert_file "lib/bukkits/engine.rb", /module Bukkits\n  class Engine < ::Rails::Engine\n  end\nend/
    assert_file "lib/bukkits.rb", /require "bukkits\/engine"/
  end

  def test_creating_engine_with_hyphenated_name_in_full_mode
    run_generator [File.join(destination_root, "hyphenated-name"), "--full"]
    assert_no_file "hyphenated-name/app/assets/javascripts/hyphenated/name"
    assert_file "hyphenated-name/app/assets/stylesheets/hyphenated/name"
    assert_file "hyphenated-name/app/assets/images/hyphenated/name"
    assert_file "hyphenated-name/app/models"
    assert_file "hyphenated-name/app/controllers"
    assert_file "hyphenated-name/app/views"
    assert_file "hyphenated-name/app/helpers"
    assert_file "hyphenated-name/app/mailers"
    assert_file "hyphenated-name/app/jobs"
    assert_file "hyphenated-name/bin/rails"
    assert_file "hyphenated-name/config/routes.rb",              /Rails.application.routes.draw do/
    assert_file "hyphenated-name/lib/hyphenated/name/engine.rb", /module Hyphenated\n  module Name\n    class Engine < ::Rails::Engine\n    end\n  end\nend/
    assert_file "hyphenated-name/lib/hyphenated/name.rb",        /require "hyphenated\/name\/engine"/
    assert_file "hyphenated-name/bin/rails",                     /\.\.\/lib\/hyphenated\/name\/engine/
  end

  def test_creating_engine_with_hyphenated_and_underscored_name_in_full_mode
    run_generator [File.join(destination_root, "my_hyphenated-name"), "--full"]
    assert_no_file "my_hyphenated-name/app/assets/javascripts/my_hyphenated/name"
    assert_file "my_hyphenated-name/app/assets/stylesheets/my_hyphenated/name"
    assert_file "my_hyphenated-name/app/assets/images/my_hyphenated/name"
    assert_file "my_hyphenated-name/app/models"
    assert_file "my_hyphenated-name/app/controllers"
    assert_file "my_hyphenated-name/app/views"
    assert_file "my_hyphenated-name/app/helpers"
    assert_file "my_hyphenated-name/app/mailers"
    assert_file "my_hyphenated-name/app/jobs"
    assert_file "my_hyphenated-name/bin/rails"
    assert_file "my_hyphenated-name/config/routes.rb",              /Rails\.application\.routes\.draw do/
    assert_file "my_hyphenated-name/lib/my_hyphenated/name/engine.rb", /module MyHyphenated\n  module Name\n    class Engine < ::Rails::Engine\n    end\n  end\nend/
    assert_file "my_hyphenated-name/lib/my_hyphenated/name.rb",        /require "my_hyphenated\/name\/engine"/
    assert_file "my_hyphenated-name/bin/rails",                     /\.\.\/lib\/my_hyphenated\/name\/engine/
  end

  def test_being_quiet_while_creating_dummy_application
    assert_no_match(/create\s+config\/application\.rb/, run_generator)
  end

  def test_create_mountable_application_with_mountable_option
    run_generator [destination_root, "--mountable"]
    assert_no_file "app/assets/javascripts/bukkits"
    assert_file "app/assets/stylesheets/bukkits"
    assert_file "app/assets/images/bukkits"
    assert_file "config/routes.rb", /Bukkits::Engine\.routes\.draw do/
    assert_file "lib/bukkits/engine.rb", /isolate_namespace Bukkits/
    assert_file "test/dummy/config/routes.rb", /mount Bukkits::Engine => "\/bukkits"/
    assert_file "app/controllers/bukkits/application_controller.rb", /module Bukkits\n  class ApplicationController < ActionController::Base/
    assert_file "app/models/bukkits/application_record.rb", /module Bukkits\n  class ApplicationRecord < ActiveRecord::Base/
    assert_file "app/jobs/bukkits/application_job.rb", /module Bukkits\n  class ApplicationJob < ActiveJob::Base/
    assert_file "app/mailers/bukkits/application_mailer.rb", /module Bukkits\n  class ApplicationMailer < ActionMailer::Base\n    default from: "from@example\.com"\n    layout "mailer"\n/
    assert_file "app/helpers/bukkits/application_helper.rb", /module Bukkits\n  module ApplicationHelper/
    assert_file "app/views/layouts/bukkits/application.html.erb" do |contents|
      assert_match "<title>Bukkits</title>", contents
      assert_match "<%= csrf_meta_tags %>", contents
      assert_match "<%= csp_meta_tag %>", contents
      assert_match(/stylesheet_link_tag\s+['"]bukkits\/application['"]/, contents)
      assert_no_match(/javascript_include_tag\s+['"]bukkits\/application['"]/, contents)
      assert_match "<%= yield %>", contents
    end
    assert_file "test/test_helper.rb" do |content|
      assert_match(/ActiveRecord::Migrator\.migrations_paths.+\.\.\/test\/dummy\/db\/migrate/, content)
      assert_match(/ActiveRecord::Migrator\.migrations_paths.+<<.+\.\.\/db\/migrate/, content)
      assert_match(/ActionDispatch::IntegrationTest\.fixture_paths = ActiveSupport::TestCase\.fixture_pat/, content)
      assert_no_match(/Rails::TestUnitReporter\.executable = "bin\/test"/, content)
    end
    assert_no_file "bin/test"
  end

  def test_create_mountable_application_with_mountable_option_and_hyphenated_name
    run_generator [File.join(destination_root, "hyphenated-name"), "--mountable"]
    assert_no_file "hyphenated-name/app/assets/javascripts/hyphenated/name"
    assert_file "hyphenated-name/app/assets/stylesheets/hyphenated/name"
    assert_file "hyphenated-name/app/assets/images/hyphenated/name"
    assert_file "hyphenated-name/config/routes.rb",                                          /Hyphenated::Name::Engine\.routes\.draw do/
    assert_file "hyphenated-name/lib/hyphenated/name/version.rb",                            /module Hyphenated\n  module Name\n    VERSION = "0\.1\.0"\n  end\nend/
    assert_file "hyphenated-name/lib/hyphenated/name/engine.rb",                             /module Hyphenated\n  module Name\n    class Engine < ::Rails::Engine\n      isolate_namespace Hyphenated::Name\n    end\n  end\nend/
    assert_file "hyphenated-name/lib/hyphenated/name.rb",                                    /require "hyphenated\/name\/engine"/
    assert_file "hyphenated-name/test/dummy/config/routes.rb",                               /mount Hyphenated::Name::Engine => "\/hyphenated-name"/
    assert_file "hyphenated-name/app/controllers/hyphenated/name/application_controller.rb", /module Hyphenated\n  module Name\n    class ApplicationController < ActionController::Base\n    end\n  end\nend\n/
    assert_file "hyphenated-name/app/models/hyphenated/name/application_record.rb",          /module Hyphenated\n  module Name\n    class ApplicationRecord < ActiveRecord::Base\n      self.abstract_class = true\n    end\n  end\nend/
    assert_file "hyphenated-name/app/jobs/hyphenated/name/application_job.rb",               /module Hyphenated\n  module Name\n    class ApplicationJob < ActiveJob::Base/
    assert_file "hyphenated-name/app/mailers/hyphenated/name/application_mailer.rb",         /module Hyphenated\n  module Name\n    class ApplicationMailer < ActionMailer::Base\n      default from: "from@example\.com"\n      layout "mailer"\n    end\n  end\nend/
    assert_file "hyphenated-name/app/helpers/hyphenated/name/application_helper.rb",         /module Hyphenated\n  module Name\n    module ApplicationHelper\n    end\n  end\nend/
    assert_file "hyphenated-name/app/views/layouts/hyphenated/name/application.html.erb" do |contents|
      assert_match "<title>Hyphenated name</title>", contents
      assert_match(/stylesheet_link_tag\s+['"]hyphenated\/name\/application['"]/, contents)
      assert_no_match(/javascript_include_tag\s+['"]hyphenated\/name\/application['"]/, contents)
    end
  end

  def test_create_mountable_application_with_mountable_option_and_hyphenated_and_underscored_name
    run_generator [File.join(destination_root, "my_hyphenated-name"), "--mountable"]
    assert_no_file "my_hyphenated-name/app/assets/javascripts/my_hyphenated/name"
    assert_file "my_hyphenated-name/app/assets/stylesheets/my_hyphenated/name"
    assert_file "my_hyphenated-name/app/assets/images/my_hyphenated/name"
    assert_file "my_hyphenated-name/config/routes.rb",                                             /MyHyphenated::Name::Engine\.routes\.draw do/
    assert_file "my_hyphenated-name/lib/my_hyphenated/name/version.rb",                            /module MyHyphenated\n  module Name\n    VERSION = "0\.1\.0"\n  end\nend/
    assert_file "my_hyphenated-name/lib/my_hyphenated/name/engine.rb",                             /module MyHyphenated\n  module Name\n    class Engine < ::Rails::Engine\n      isolate_namespace MyHyphenated::Name\n    end\n  end\nend/
    assert_file "my_hyphenated-name/lib/my_hyphenated/name.rb",                                    /require "my_hyphenated\/name\/engine"/
    assert_file "my_hyphenated-name/test/dummy/config/routes.rb",                                  /mount MyHyphenated::Name::Engine => "\/my_hyphenated-name"/
    assert_file "my_hyphenated-name/app/controllers/my_hyphenated/name/application_controller.rb", /module MyHyphenated\n  module Name\n    class ApplicationController < ActionController::Base\n    end\n  end\nend\n/
    assert_file "my_hyphenated-name/app/models/my_hyphenated/name/application_record.rb",          /module MyHyphenated\n  module Name\n    class ApplicationRecord < ActiveRecord::Base\n      self.abstract_class = true\n    end\n  end\nend/
    assert_file "my_hyphenated-name/app/jobs/my_hyphenated/name/application_job.rb",               /module MyHyphenated\n  module Name\n    class ApplicationJob < ActiveJob::Base/
    assert_file "my_hyphenated-name/app/mailers/my_hyphenated/name/application_mailer.rb",         /module MyHyphenated\n  module Name\n    class ApplicationMailer < ActionMailer::Base\n      default from: "from@example\.com"\n      layout "mailer"\n    end\n  end\nend/
    assert_file "my_hyphenated-name/app/helpers/my_hyphenated/name/application_helper.rb",         /module MyHyphenated\n  module Name\n    module ApplicationHelper\n    end\n  end\nend/
    assert_file "my_hyphenated-name/app/views/layouts/my_hyphenated/name/application.html.erb" do |contents|
      assert_match "<title>My hyphenated name</title>", contents
      assert_match(/stylesheet_link_tag\s+['"]my_hyphenated\/name\/application['"]/, contents)
      assert_no_match(/javascript_include_tag\s+['"]my_hyphenated\/name\/application['"]/, contents)
    end
  end

  def test_create_mountable_application_with_mountable_option_and_multiple_hyphenates_in_name
    run_generator [File.join(destination_root, "deep-hyphenated-name"), "--mountable"]
    assert_no_file "deep-hyphenated-name/app/assets/javascripts/deep/hyphenated/name"
    assert_file "deep-hyphenated-name/app/assets/stylesheets/deep/hyphenated/name"
    assert_file "deep-hyphenated-name/app/assets/images/deep/hyphenated/name"
    assert_file "deep-hyphenated-name/config/routes.rb",                                               /Deep::Hyphenated::Name::Engine\.routes\.draw do/
    assert_file "deep-hyphenated-name/lib/deep/hyphenated/name/version.rb",                            /module Deep\n  module Hyphenated\n    module Name\n      VERSION = "0\.1\.0"\n    end\n  end\nend/
    assert_file "deep-hyphenated-name/lib/deep/hyphenated/name/engine.rb",                             /module Deep\n  module Hyphenated\n    module Name\n      class Engine < ::Rails::Engine\n        isolate_namespace Deep::Hyphenated::Name\n      end\n    end\n  end\nend/
    assert_file "deep-hyphenated-name/lib/deep/hyphenated/name.rb",                                    /require "deep\/hyphenated\/name\/engine"/
    assert_file "deep-hyphenated-name/test/dummy/config/routes.rb",                                    /mount Deep::Hyphenated::Name::Engine => "\/deep-hyphenated-name"/
    assert_file "deep-hyphenated-name/app/controllers/deep/hyphenated/name/application_controller.rb", /module Deep\n  module Hyphenated\n    module Name\n      class ApplicationController < ActionController::Base\n      end\n    end\n  end\nend\n/
    assert_file "deep-hyphenated-name/app/models/deep/hyphenated/name/application_record.rb",          /module Deep\n  module Hyphenated\n    module Name\n      class ApplicationRecord < ActiveRecord::Base\n        self.abstract_class = true\n      end\n    end\n  end\nend/
    assert_file "deep-hyphenated-name/app/jobs/deep/hyphenated/name/application_job.rb",               /module Deep\n  module Hyphenated\n    module Name\n      class ApplicationJob < ActiveJob::Base/
    assert_file "deep-hyphenated-name/app/mailers/deep/hyphenated/name/application_mailer.rb",         /module Deep\n  module Hyphenated\n    module Name\n      class ApplicationMailer < ActionMailer::Base\n        default from: "from@example\.com"\n        layout "mailer"\n      end\n    end\n  end\nend/
    assert_file "deep-hyphenated-name/app/helpers/deep/hyphenated/name/application_helper.rb",         /module Deep\n  module Hyphenated\n    module Name\n      module ApplicationHelper\n      end\n    end\n  end\nend/
    assert_file "deep-hyphenated-name/app/views/layouts/deep/hyphenated/name/application.html.erb" do |contents|
      assert_match "<title>Deep hyphenated name</title>", contents
      assert_match(/stylesheet_link_tag\s+['"]deep\/hyphenated\/name\/application['"]/, contents)
      assert_no_match(/javascript_include_tag\s+['"]deep\/hyphenated\/name\/application['"]/, contents)
    end
  end

  def test_creating_full_engine_mode_adds_keeps
    run_generator [destination_root, "--full"]
    folders_with_keep = %w(
      app/models/concerns
      app/controllers/concerns
      test/fixtures/files
      test/controllers
      test/mailers
      test/models
      test/helpers
      test/integration
    )
    folders_with_keep.each do |folder|
      assert_file("#{folder}/.keep")
    end
  end

  def test_creating_full_api_engine_adds_keeps
    run_generator [destination_root, "--full", "--api"]
    folders_with_keep = %w(
      app/models/concerns
      app/controllers/concerns
      test/fixtures/files
      test/controllers
      test/mailers
      test/models
      test/integration
    )
    folders_with_keep.each do |folder|
      assert_file("#{folder}/.keep")
    end
    assert_no_file("test/helpers/.keep")
  end

  def test_creating_mountable_engine_mode_adds_keeps
    run_generator [destination_root, "--mountable"]
    folders_with_keep = %w(
      app/models/concerns
      app/controllers/concerns
      test/fixtures/files
      test/controllers
      test/mailers
      test/models
      test/helpers
      test/integration
    )
    folders_with_keep.each do |folder|
      assert_file("#{folder}/.keep")
    end
  end

  def test_creating_gemspec
    run_generator
    assert_file "bukkits.gemspec", /spec\.name\s+= "bukkits"/
    assert_file "bukkits.gemspec", /spec\.files = Dir.chdir\(File\.expand_path\(__dir__\)\)\s+do\s+Dir\["\{app,config,db,lib\}\/\*\*\/\*", "MIT-LICENSE", "Rakefile", "README\.md"\]\s+end/
    assert_file "bukkits.gemspec", /spec\.version\s+ = Bukkits::VERSION/
  end

  def test_gemspec_uses_optimistic_rails_version_constraint
    rails_version = "1.2.3.4.pre5"

    Rails.stub(:gem_version, Gem::Version.new(rails_version)) do
      run_generator
    end

    assert_file "bukkits.gemspec", /add_dependency "rails", ">= #{Regexp.escape rails_version}"/
  end

  def test_usage_of_engine_commands
    run_generator [destination_root, "--full"]
    assert_file "bin/rails", /ENGINE_PATH = File\.expand_path\("\.\.\/lib\/bukkits\/engine", __dir__\)/
    assert_file "bin/rails", /ENGINE_ROOT = File\.expand_path\("\.\.", __dir__\)/
    assert_file "bin/rails", %r|APP_PATH = File\.expand_path\("\.\./test/dummy/config/application", __dir__\)|
    assert_file "bin/rails", /require "rails\/all"/
    assert_file "bin/rails", /require "rails\/engine\/commands"/
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
      assert_match(/require_relative.+spec\/dummy\/config\/environment/, content)
      assert_match(/ActiveRecord::Migrator\.migrations_paths.+spec\/dummy\/db\/migrate/, content)
    end
  end

  def test_creating_dummy_application_with_different_name
    run_generator [destination_root, "--dummy_path", "spec/fake"]
    assert_file "spec/fake"
    assert_file "spec/fake/config/application.rb"
    assert_no_file "test/dummy"
    assert_file "test/test_helper.rb" do |content|
      assert_match(/require_relative.+spec\/fake\/config\/environment/, content)
      assert_match(/ActiveRecord::Migrator\.migrations_paths.+spec\/fake\/db\/migrate/, content)
    end
  end

  def test_creating_dummy_without_tests_but_with_dummy_path
    run_generator [destination_root, "--dummy_path", "spec/dummy", "--skip-test"]
    assert_directory "spec/dummy"
    assert_file "spec/dummy/config/application.rb", /#\s+require\s+["']rails\/test_unit\/railtie["']/
    assert_no_directory "test"
    assert_file ".gitignore" do |contents|
      assert_match(/spec\/dummy/, contents)
    end
  end

  def test_plugin_passes_generated_test
    run_generator
    prepare_plugin(destination_root)

    in_plugin_context(destination_root) do
      output = `bin/test 2>&1`
      assert_predicate $?, :success?, "Command failed: #{output}"
    end
  end

  def test_dummy_application_sets_include_all_helpers_to_false_for_mountable
    run_generator [destination_root, "--mountable"]

    assert_file "test/dummy/config/application.rb", /^    config\.action_controller\.include_all_helpers = false$/
  end

  def test_dummy_application_sets_include_all_helpers_to_false_for_full
    run_generator [destination_root, "--full"]

    assert_file "test/dummy/config/application.rb", /include_all_helpers/
  end

  def test_dummy_application_does_not_set_include_all_helpers_for_regular
    run_generator

    assert_file "test/dummy/config/application.rb" do |content|
      assert_no_match(/include_all_helpers/, content)
    end
  end

  def test_dummy_application_does_not_set_include_all_helpers_for_api
    run_generator [destination_root, "--mountable", "--api"]

    assert_file "test/dummy/config/application.rb" do |content|
      assert_no_match(/include_all_helpers/, content)
    end
  end

  def test_dummy_application_uses_dynamic_rails_version_number
    run_generator

    assert_file "test/dummy/config/application.rb" do |contents|
      assert_match(/^\s*config\.load_defaults Rails::VERSION::STRING\.to_f/, contents)
    end
  end

  def test_ensure_that_gitignore_can_be_generated_from_a_template_for_dummy_path
    FileUtils.cd(Rails.root)
    run_generator([destination_root, "--dummy_path", "spec/dummy", "--skip-test"])
    assert_file ".gitignore" do |contents|
      assert_match(/spec\/dummy/, contents)
    end
  end

  def test_skipping_test_files
    run_generator [destination_root, "--skip-test"]
    assert_no_directory "test"
    assert_file ".gitignore" do |contents|
      assert_no_match(/test\/dummy/, contents)
    end
  end

  def test_dummy_application_skips_asset_pipeline_when_simple_railtie
    run_generator

    assert_no_gem "propshaft"
    assert_no_file "test/dummy/config/initializers/assets.rb"
    assert_file "test/dummy/config/environments/development.rb" do |content|
      assert_no_match "config.assets", content
    end
  end

  def test_dummy_application_configures_asset_pipeline_when_mountable
    run_generator [destination_root, "--mountable"]

    assert_gem "propshaft"
    assert_file "test/dummy/config/initializers/assets.rb"
  end

  def test_dummy_application_configures_asset_pipeline_when_full
    run_generator [destination_root, "--full"]

    assert_gem "propshaft"
    assert_file "test/dummy/config/initializers/assets.rb"
    assert_file "test/dummy/config/environments/development.rb"
  end

  def test_dummy_application_skips_asset_pipeline_when_flag_skip_asset_pipeline
    run_generator [destination_root, "--mountable", "--skip-asset-pipeline"]

    assert_no_gem "propshaft"
    assert_no_file "test/dummy/config/initializers/assets.rb"
    assert_file "test/dummy/config/environments/development.rb" do |content|
      assert_no_match "config.assets", content
    end
  end

  def test_no_asset_pipeline_gem_when_no_dummy_application
    run_generator [destination_root, "--mountable", "--skip-test"]

    assert_no_gem "propshaft"
    assert_no_directory "test/dummy"
  end

  def test_skipping_gemspec
    run_generator [destination_root, "--skip-gemspec"]
    assert_no_file "bukkits.gemspec"
    assert_file "Gemfile" do |contents|
      assert_no_match("gemspec", contents)
      assert_match(/gem "rails"/, contents)
    end
  end

  def test_skipping_gemspec_in_full_mode
    run_generator [destination_root, "--skip-gemspec", "--full"]
    assert_no_file "bukkits.gemspec"
    assert_file "Gemfile" do |contents|
      assert_no_match("gemspec", contents)
      assert_match(/gem "rails"/, contents)
    end
  end

  def test_creating_plugin_in_app_directory_adds_gemfile_entry
    with_simulated_app do |gemfile_path|
      File.write(gemfile_path, "#foo")

      run_generator

      assert_file gemfile_path, /^gem "bukkits", path: "tmp\/bukkits"/
    end
  end

  def test_creating_plugin_only_specify_plugin_name_in_app_directory_adds_gemfile_entry
    with_simulated_app do |gemfile_path|
      FileUtils.cd(destination_root)
      run_generator ["bukkits"]

      assert_file gemfile_path, /gem "bukkits", path: "bukkits"/
    end
  end

  def test_skipping_gemfile_entry
    with_simulated_app do |gemfile_path|
      run_generator [destination_root, "--skip-gemfile-entry"]

      assert_file gemfile_path do |contents|
        assert_no_match(/gem "bukkits", path: "tmp\/bukkits"/, contents)
      end
    end
  end

  def test_creating_plugin_in_application_skips_license
    with_simulated_app do |gemfile_path|
      FileUtils.cd(destination_root)
      run_generator ["bukkits"]

      assert_file "bukkits/bukkits.gemspec" do |contents|
        assert_no_match(/spec.license/, contents)
      end
      assert_no_file "bukkits/MIT-LICENSE"
    end
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

  def test_no_year_in_license_file
    year = Date.today.year

    run_generator
    assert_file "MIT-LICENSE" do |contents|
      assert_no_match(/#{year}/, contents)
    end
  end

  def test_no_details_from_git_when_skip_git
    name = "TODO: Write your name"
    email = "TODO: Write your email address"

    run_generator [destination_root, "--skip-git"]
    assert_file "MIT-LICENSE" do |contents|
      assert_match name, contents
    end
    assert_file "bukkits.gemspec" do |contents|
      assert_match name, contents
      assert_match email, contents
    end
    assert_no_directory ".git"
  end

  def test_skipping_useless_folders_generation_for_api_engines
    ["--full", "--mountable"].each do |option|
      run_generator [destination_root, option, "--api"]

      assert_no_directory "app/assets"
      assert_no_directory "app/helpers"
      assert_no_directory "app/views"

      FileUtils.rm_rf destination_root
    end
  end

  def test_application_controller_parent_for_mountable_api_plugins
    run_generator [destination_root, "--mountable", "--api"]

    assert_file "app/controllers/bukkits/application_controller.rb" do |content|
      assert_match "ApplicationController < ActionController::API", content
    end
  end

  def test_dummy_api_application_for_api_plugins
    run_generator [destination_root, "--api"]

    assert_file "test/dummy/config/application.rb" do |content|
      assert_match "config.api_only = true", content
    end
  end

  def test_api_generators_configuration_for_api_engines
    run_generator [destination_root, "--full", "--api"]

    assert_file "lib/bukkits/engine.rb" do |content|
      assert_match "config.generators.api_only = true", content
    end
  end

  def test_scaffold_generator_for_mountable_api_plugins
    run_generator [destination_root, "--mountable", "--api"]

    capture(:stdout) do
      `#{destination_root}/bin/rails g scaffold article`
    end

    assert_file "app/models/bukkits/article.rb"
    assert_file "app/controllers/bukkits/articles_controller.rb" do |content|
      assert_match "only: %i[ show update destroy ]", content
    end

    assert_no_directory "app/assets"
    assert_no_directory "app/helpers"
    assert_no_directory "app/views"
  end

  def test_model_with_existent_application_record_in_mountable_engine
    run_generator [destination_root, "--mountable"]
    capture(:stdout) do
      `#{destination_root}/bin/rails g model article`
    end

    assert_file "app/models/bukkits/article.rb", /class Article < ApplicationRecord/
  end

  def test_generate_application_mailer_when_does_not_exist_in_mountable_engine
    run_generator [destination_root, "--mountable"]
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
    run_generator [destination_root, "--mountable"]
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
    run_generator [destination_root, "--mountable"]
    FileUtils.rm "#{destination_root}/app/jobs/bukkits/application_job.rb"
    capture(:stdout) do
      `#{destination_root}/bin/rails g job refresh_counters`
    end

    assert_file "#{destination_root}/app/jobs/bukkits/application_job.rb" do |record|
      assert_match(/module Bukkits/, record)
      assert_match(/class ApplicationJob < ActiveJob::Base/, record)
    end
  end

  def test_app_update_generates_bin_file
    run_generator [destination_root, "--mountable"]

    Object.const_set("ENGINE_ROOT", destination_root)
    FileUtils.rm("#{destination_root}/bin/rails")

    quietly { Rails::Engine::Updater.run(:create_bin_files) }

    assert_file "#{destination_root}/bin/rails" do |content|
      assert_match(%r|APP_PATH = File\.expand_path\("\.\./test/dummy/config/application", __dir__\)|, content)
    end
  ensure
    Object.send(:remove_const, "ENGINE_ROOT")
  end

  def test_railtie_test_command
    run_generator [destination_root]
    assert_file ".github/workflows/ci.yml", /run: bin\/test/
  end

  def test_engine_test_command
    run_generator [destination_root, "--full"]
    assert_file ".github/workflows/ci.yml", /run: bin\/rails db:test:prepare test/
  end

  def test_engine_without_active_record_test_command
    run_generator [destination_root, "--full", "--skip-active-record"]
    assert_file ".github/workflows/ci.yml", /run: bin\/rails test/
  end

  private
    def action(*args, &block)
      silence(:stdout) { generator.send(*args, &block) }
    end

    def default_files
      ::DEFAULT_PLUGIN_FILES
    end

    def with_simulated_app
      gemfile_path = "#{Rails.root}/Gemfile"
      Object.const_set("APP_PATH", Rails.root)
      FileUtils.touch gemfile_path

      yield gemfile_path
    ensure
      Object.send(:remove_const, "APP_PATH")
      FileUtils.rm gemfile_path
    end
end
