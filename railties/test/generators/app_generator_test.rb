# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/app/app_generator"
require "generators/shared_generator_tests"

DEFAULT_APP_FILES = %w(
  .gitattributes
  .gitignore
  .ruby-version
  README.md
  Gemfile
  Rakefile
  config.ru
  app/assets/config/manifest.js
  app/assets/images
  app/javascript
  app/javascript/channels
  app/javascript/channels/consumer.js
  app/javascript/channels/index.js
  app/javascript/packs/application.js
  app/assets/stylesheets
  app/assets/stylesheets/application.css
  app/channels/application_cable/channel.rb
  app/channels/application_cable/connection.rb
  app/controllers
  app/controllers/application_controller.rb
  app/controllers/concerns
  app/helpers
  app/helpers/application_helper.rb
  app/mailers
  app/mailers/application_mailer.rb
  app/models
  app/models/application_record.rb
  app/models/concerns
  app/jobs
  app/jobs/application_job.rb
  app/views/layouts
  app/views/layouts/application.html.erb
  app/views/layouts/mailer.html.erb
  app/views/layouts/mailer.text.erb
  bin/rails
  bin/rake
  bin/setup
  bin/yarn
  config/application.rb
  config/boot.rb
  config/cable.yml
  config/environment.rb
  config/environments
  config/environments/development.rb
  config/environments/production.rb
  config/environments/test.rb
  config/initializers
  config/initializers/application_controller_renderer.rb
  config/initializers/assets.rb
  config/initializers/backtrace_silencers.rb
  config/initializers/cookies_serializer.rb
  config/initializers/content_security_policy.rb
  config/initializers/filter_parameter_logging.rb
  config/initializers/inflections.rb
  config/initializers/mime_types.rb
  config/initializers/wrap_parameters.rb
  config/locales
  config/locales/en.yml
  config/puma.rb
  config/routes.rb
  config/credentials.yml.enc
  config/spring.rb
  config/storage.yml
  db
  db/seeds.rb
  lib
  lib/tasks
  lib/assets
  log
  package.json
  public
  storage
  test/application_system_test_case.rb
  test/test_helper.rb
  test/fixtures
  test/fixtures/files
  test/channels/application_cable/connection_test.rb
  test/controllers
  test/models
  test/helpers
  test/mailers
  test/integration
  test/system
  vendor
  tmp
  tmp/cache
  tmp/cache/assets
  tmp/storage
)

class AppGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments [destination_root]

  # brings setup, teardown, and some tests
  include SharedGeneratorTests

  def default_files
    ::DEFAULT_APP_FILES
  end

  def test_skip_bundle
    generator([destination_root], skip_bundle: true, skip_webpack_install: true)
    run_generator_instance

    assert_empty @bundle_commands
    # skip_bundle is only about running bundle install so ensure the Gemfile is still generated
    assert_file "Gemfile"
  end

  def test_assets
    run_generator

    assert_file("app/views/layouts/application.html.erb", /stylesheet_link_tag\s+'application', media: 'all', 'data-turbolinks-track': 'reload'/)
    assert_file("app/views/layouts/application.html.erb", /javascript_pack_tag\s+'application', 'data-turbolinks-track': 'reload'/)
    assert_file("app/assets/stylesheets/application.css")
    assert_file("app/javascript/packs/application.js")
  end

  def test_application_job_file_present
    run_generator
    assert_file("app/jobs/application_job.rb")
  end

  def test_invalid_application_name_raises_an_error
    content = capture(:stderr) { run_generator [File.join(destination_root, "43-things")] }
    assert_equal "Invalid application name 43-things. Please give a name which does not start with numbers.\n", content
  end

  def test_invalid_application_name_is_fixed
    run_generator [File.join(destination_root, "things-43")]
    assert_file "things-43/config/environment.rb", /Rails\.application\.initialize!/
    assert_file "things-43/config/application.rb", /^module Things43$/
  end

  def test_application_new_exits_with_non_zero_code_on_invalid_application_name
    quietly { system "rails new test --no-rc" }
    assert_equal false, $?.success?
  end

  def test_application_new_exits_with_message_and_non_zero_code_when_generating_inside_existing_rails_directory
    app_root = File.join(destination_root, "myfirstapp")
    run_generator [app_root]
    output = nil
    Dir.chdir(app_root) do
      output = `rails new mysecondapp`
    end
    assert_equal "Can't initialize a new Rails application within the directory of another, please change to a non-Rails directory first.\nType 'rails' for help.\n", output
    assert_equal false, $?.success?
  end

  def test_application_new_show_help_message_inside_existing_rails_directory
    app_root = File.join(destination_root, "myfirstapp")
    run_generator [app_root]
    output = Dir.chdir(app_root) do
      `rails new --help`
    end
    assert_match(/rails new APP_PATH \[options\]/, output)
    assert_equal true, $?.success?
  end

  def test_application_name_is_detected_if_it_exists_and_app_folder_renamed
    app_root       = File.join(destination_root, "myapp")
    app_moved_root = File.join(destination_root, "myapp_moved")

    run_generator [app_root]

    stub_rails_application(app_moved_root) do
      Rails.application.stub(:is_a?, -> *args { Rails::Application }) do
        FileUtils.mv(app_root, app_moved_root)

        # make sure we are in correct dir
        FileUtils.cd(app_moved_root)

        generator = Rails::Generators::AppGenerator.new ["rails"], [],
                                                                   destination_root: app_moved_root, shell: @shell
        generator.send(:app_const)
        quietly { generator.update_config_files }
        assert_file "myapp_moved/config/environment.rb", /Rails\.application\.initialize!/
      end
    end
  end

  def test_new_application_use_json_serializer
    run_generator

    assert_file("config/initializers/cookies_serializer.rb", /Rails\.application\.config\.action_dispatch\.cookies_serializer = :json/)
  end

  def test_new_application_not_include_api_initializers
    run_generator

    assert_no_file "config/initializers/cors.rb"
  end

  def test_new_application_doesnt_need_defaults
    run_generator
    assert_no_file "config/initializers/new_framework_defaults_6_2.rb"
  end

  def test_new_application_load_defaults
    app_root = File.join(destination_root, "myfirstapp")
    run_generator [app_root]
    assert_file "#{app_root}/config/application.rb", /\s+config\.load_defaults #{Rails::VERSION::STRING.to_f}/
  end

  def test_csp_initializer_include_connect_src_example
    run_generator

    assert_file "config/initializers/content_security_policy.rb" do |content|
      assert_match(/#   policy\.connect_src/, content)
    end
  end

  def test_app_update_keep_the_cookie_serializer_if_it_is_already_configured
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.update_config_files }
      assert_file("#{app_root}/config/initializers/cookies_serializer.rb", /Rails\.application\.config\.action_dispatch\.cookies_serializer = :json/)
    end
  end

  def test_app_update_set_the_cookie_serializer_to_marshal_if_it_is_not_already_configured
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root]

    FileUtils.rm("#{app_root}/config/initializers/cookies_serializer.rb")

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.update_config_files }
      assert_file("#{app_root}/config/initializers/cookies_serializer.rb",
                  /Valid options are :json, :marshal, and :hybrid\.\nRails\.application\.config\.action_dispatch\.cookies_serializer = :marshal/)
    end
  end

  def test_app_update_create_new_framework_defaults
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root]

    assert_no_file "#{app_root}/config/initializers/new_framework_defaults_6_2.rb"

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], { update: true }, { destination_root: app_root, shell: @shell }
      generator.send(:app_const)
      quietly { generator.update_config_files }

      assert_file "#{app_root}/config/initializers/new_framework_defaults_6_2.rb"
    end
  end

  def test_app_update_does_not_create_rack_cors
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.update_config_files }
      assert_no_file "#{app_root}/config/initializers/cors.rb"
    end
  end

  def test_app_update_does_not_remove_rack_cors_if_already_present
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root]

    FileUtils.touch("#{app_root}/config/initializers/cors.rb")

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.update_config_files }
      assert_file "#{app_root}/config/initializers/cors.rb"
    end
  end

  def test_adds_bin_yarn_into_setup_script
    run_generator

    assert_file "bin/yarn"

    assert_file "bin/setup" do |content|
      # Does not comment yarn install
      assert_match(/(?=[^#]*?) system! 'bin\/yarn'/, content)
    end
  end

  def test_app_update_does_not_generate_yarn_contents_when_bin_yarn_is_not_used
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root, "--skip-javascript"]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], { update: true, skip_javascript: true }, { destination_root: app_root, shell: @shell }
      generator.send(:app_const)
      quietly { generator.update_bin_files }

      assert_no_file "#{app_root}/bin/yarn"

      assert_file "#{app_root}/bin/setup" do |content|
        assert_no_match(/system! 'bin\/yarn'/, content)
      end
    end
  end

  def test_app_update_does_not_generate_assets_initializer_when_skip_sprockets_is_given
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root, "--skip-sprockets"]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], { update: true, skip_sprockets: true }, { destination_root: app_root, shell: @shell }
      generator.send(:app_const)
      quietly { generator.update_config_files }

      assert_no_file "#{app_root}/config/initializers/assets.rb"
      assert_no_file "#{app_root}/app/assets/config/manifest.js"
      assert_no_file "#{app_root}/app/assets/stylesheets/application.css"
    end
  end

  def test_app_update_does_not_generate_spring_contents_when_skip_spring_is_given
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root, "--skip-spring"]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], { update: true, skip_spring: true }, { destination_root: app_root, shell: @shell }
      generator.send(:app_const)
      quietly { generator.update_config_files }

      assert_no_file "#{app_root}/config/spring.rb"
    end
  end

  def test_app_update_does_not_generate_action_cable_contents_when_skip_action_cable_is_given
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root, "--skip-action-cable"]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], { update: true, skip_action_cable: true }, { destination_root: app_root, shell: @shell }
      generator.send(:app_const)
      quietly { generator.update_config_files }

      assert_no_file "#{app_root}/config/cable.yml"
      assert_file "#{app_root}/config/environments/production.rb" do |content|
        assert_no_match(/config\.action_cable/, content)
      end
      assert_no_file "#{app_root}/test/channels/application_cable/connection_test.rb"
    end
  end

  def test_app_update_does_not_generate_bootsnap_contents_when_skip_bootsnap_is_given
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root, "--skip-bootsnap"]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], { update: true, skip_bootsnap: true }, { destination_root: app_root, shell: @shell }
      generator.send(:app_const)
      quietly { generator.update_config_files }

      assert_file "#{app_root}/config/boot.rb" do |content|
        assert_no_match(/require "bootsnap\/setup"/, content)
      end
    end
  end

  def test_gem_for_active_storage
    run_generator
    assert_file "Gemfile", /^# gem 'image_processing'/
  end

  def test_gem_for_active_storage_when_skip_active_storage_is_given
    run_generator [destination_root, "--skip-active-storage"]

    assert_no_gem "image_processing"
  end

  def test_app_update_does_not_generate_active_storage_contents_when_skip_active_storage_is_given
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root, "--skip-active-storage"]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], { update: true, skip_active_storage: true }, { destination_root: app_root, shell: @shell }
      generator.send(:app_const)
      quietly { generator.update_config_files }

      assert_file "#{app_root}/config/environments/development.rb" do |content|
        assert_no_match(/config\.active_storage/, content)
      end

      assert_file "#{app_root}/config/environments/production.rb" do |content|
        assert_no_match(/config\.active_storage/, content)
      end

      assert_file "#{app_root}/config/environments/test.rb" do |content|
        assert_no_match(/config\.active_storage/, content)
      end

      assert_no_file "#{app_root}/config/storage.yml"
    end
  end

  def test_app_update_does_not_generate_active_storage_contents_when_skip_active_record_is_given
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root, "--skip-active-record"]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], { update: true, skip_active_record: true }, { destination_root: app_root, shell: @shell }
      generator.send(:app_const)
      quietly { generator.update_config_files }

      assert_file "#{app_root}/config/environments/development.rb" do |content|
        assert_no_match(/config\.active_storage/, content)
      end

      assert_file "#{app_root}/config/environments/production.rb" do |content|
        assert_no_match(/config\.active_storage/, content)
      end

      assert_file "#{app_root}/config/environments/test.rb" do |content|
        assert_no_match(/config\.active_storage/, content)
      end

      assert_no_file "#{app_root}/config/storage.yml"
    end
  end

  def test_generator_skips_action_mailbox_when_skip_action_mailbox_is_given
    run_generator [destination_root, "--skip-action-mailbox"]
    assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']action_mailbox\/engine["']/
  end

  def test_generator_skips_action_mailbox_when_skip_active_record_is_given
    run_generator [destination_root, "--skip-active-record"]
    assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']action_mailbox\/engine["']/
  end

  def test_generator_skips_action_mailbox_when_skip_active_storage_is_given
    run_generator [destination_root, "--skip-active-storage"]
    assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']action_mailbox\/engine["']/
  end

  def test_generator_skips_action_text_when_skip_action_text_is_given
    run_generator [destination_root, "--skip-action-text"]
    assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']action_text\/engine["']/
  end

  def test_generator_skips_action_text_when_skip_active_record_is_given
    run_generator [destination_root, "--skip-active-record"]
    assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']action_text\/engine["']/
  end

  def test_generator_skips_action_text_when_skip_active_storage_is_given
    run_generator [destination_root, "--skip-active-storage"]
    assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']action_text\/engine["']/
  end

  def test_app_update_does_not_change_config_target_version
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root, "--skip-spring"]

    FileUtils.cd(app_root) do
      config = "config/application.rb"
      content = File.read(config)
      File.write(config, content.gsub(/config\.load_defaults #{Rails::VERSION::STRING.to_f}/, "config.load_defaults 5.1"))
      quietly { system("bin/rails app:update") }
    end

    assert_file "#{app_root}/config/application.rb", /\s+config\.load_defaults 5\.1/
  end

  def test_app_update_does_not_change_app_name_when_app_name_is_hyphenated_name
    app_root = File.join(destination_root, "hyphenated-app")
    run_generator [app_root, "-d", "postgresql"]

    assert_file "#{app_root}/config/database.yml" do |content|
      assert_match(/hyphenated_app_development/, content)
      assert_no_match(/hyphenated-app_development/, content)
    end

    assert_file "#{app_root}/config/cable.yml" do |content|
      assert_match(/hyphenated_app/, content)
      assert_no_match(/hyphenated-app/, content)
    end

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], { update: true }, { destination_root: app_root, shell: @shell }
      generator.send(:app_const)
      quietly { generator.update_config_files }

      assert_file "#{app_root}/config/cable.yml" do |content|
        assert_match(/hyphenated_app/, content)
        assert_no_match(/hyphenated-app/, content)
      end
    end
  end

  def test_application_names_are_not_singularized
    run_generator [File.join(destination_root, "hats")]
    assert_file "hats/config/environment.rb", /Rails\.application\.initialize!/
  end

  def test_gemfile_has_no_whitespace_errors
    run_generator
    absolute = File.expand_path("Gemfile", destination_root)
    File.open(absolute, "r") do |f|
      f.each_line do |line|
        assert_no_match %r{/^[ \t]+$/}, line
      end
    end
  end

  def test_config_database_is_added_by_default
    run_generator
    assert_file "config/database.yml", /sqlite3/
    if defined?(JRUBY_VERSION)
      assert_gem "activerecord-jdbcsqlite3-adapter"
    else
      assert_gem "sqlite3", "'~> 1.4'"
    end
  end

  def test_config_mysql_database
    run_generator([destination_root, "-d", "mysql"])
    assert_file "config/database.yml", /mysql/
    if defined?(JRUBY_VERSION)
      assert_gem "activerecord-jdbcmysql-adapter"
    else
      assert_gem "mysql2", "'~> 0.5'"
    end
  end

  def test_config_database_app_name_with_period
    run_generator [File.join(destination_root, "common.usage.com"), "-d", "postgresql"]
    assert_file "common.usage.com/config/database.yml", /common_usage_com/
  end

  def test_config_postgresql_database
    run_generator([destination_root, "-d", "postgresql"])
    assert_file "config/database.yml", /postgresql/
    if defined?(JRUBY_VERSION)
      assert_gem "activerecord-jdbcpostgresql-adapter"
    else
      assert_gem "pg", "'~> 1.1'"
    end
  end

  def test_config_jdbcmysql_database
    run_generator([destination_root, "-d", "jdbcmysql"])
    assert_file "config/database.yml", /mysql/
    assert_gem "activerecord-jdbcmysql-adapter"
  end

  def test_config_jdbcsqlite3_database
    run_generator([destination_root, "-d", "jdbcsqlite3"])
    assert_file "config/database.yml", /sqlite3/
    assert_gem "activerecord-jdbcsqlite3-adapter"
  end

  def test_config_jdbcpostgresql_database
    run_generator([destination_root, "-d", "jdbcpostgresql"])
    assert_file "config/database.yml", /postgresql/
    assert_gem "activerecord-jdbcpostgresql-adapter"
  end

  def test_config_jdbc_database
    run_generator([destination_root, "-d", "jdbc"])
    assert_file "config/database.yml", /jdbc/
    assert_file "config/database.yml", /mssql/
    assert_gem "activerecord-jdbc-adapter"
  end

  if defined?(JRUBY_VERSION)
    def test_config_jdbc_database_when_no_option_given
      run_generator
      assert_file "config/database.yml", /sqlite3/
      assert_gem "activerecord-jdbcsqlite3-adapter"
    end
  end

  def test_generator_defaults_to_puma_version
    run_generator [destination_root]
    assert_gem "puma", "'~> 5.0'"
  end

  def test_generator_if_skip_puma_is_given
    run_generator [destination_root, "--skip-puma"]
    assert_no_file "config/puma.rb"
    assert_no_gem "puma"
  end

  def test_generator_has_assets_gems
    run_generator

    assert_gem "sass-rails"
  end

  def test_action_cable_redis_gems
    run_generator
    assert_file "Gemfile", /^# gem 'redis'/
  end

  def test_generator_if_skip_test_is_given
    run_generator [destination_root, "--skip-test"]

    assert_file "config/application.rb", /#\s+require\s+["']rails\/test_unit\/railtie["']/

    assert_no_gem "capybara"
    assert_no_gem "selenium-webdriver"
    assert_no_gem "webdrivers"

    assert_no_directory("test")
  end

  def test_generator_if_skip_jbuilder_is_given
    run_generator [destination_root, "--skip-jbuilder"]
    assert_no_gem "jbuilder"
  end

  def test_generator_if_skip_active_job_is_given
    run_generator [destination_root, "--skip-active-job"]
    assert_no_file "app/jobs/application.rb"
    assert_file "config/environments/production.rb" do |content|
      assert_no_match(/config\.active_job/, content)
    end
    assert_file "config/application.rb" do |content|
      assert_match(/#\s+require\s+["']active_job\/railtie["']/, content)
    end
  end

  def test_generator_if_skip_system_test_is_given
    run_generator [destination_root, "--skip-system-test"]
    assert_no_gem "capybara"
    assert_no_gem "selenium-webdriver"
    assert_no_gem "webdrivers"

    assert_directory("test")

    assert_no_directory("test/system")
  end

  def test_does_not_generate_system_test_files_if_skip_system_test_is_given
    run_generator [destination_root, "--skip-system-test"]

    Dir.chdir(destination_root) do
      quietly { `./bin/rails g scaffold User` }

      assert_no_file("test/application_system_test_case.rb")
      assert_no_file("test/system/users_test.rb")
    end
  end

  def test_javascript_is_skipped_if_required
    run_generator [destination_root, "--skip-javascript"]

    assert_no_file "app/javascript"

    assert_file "app/views/layouts/application.html.erb" do |contents|
      assert_match(/stylesheet_link_tag\s+'application', media: 'all' %>/, contents)
      assert_no_match(/javascript_pack_tag\s+'application'/, contents)
    end
  end

  def test_inclusion_of_jbuilder
    run_generator
    assert_gem "jbuilder"
  end

  def test_inclusion_of_a_debugger
    run_generator
    if defined?(JRUBY_VERSION) || RUBY_ENGINE == "rbx"
      assert_no_gem "byebug"
    else
      assert_gem "byebug"
    end
  end

  def test_inclusion_of_listen_related_configuration_by_default
    run_generator
    if /darwin|linux/.match?(RbConfig::CONFIG["host_os"])
      assert_listen_related_configuration
    else
      assert_no_listen_related_configuration
    end
  end

  def test_inclusion_of_listen_related_configuration_on_other_rubies
    ruby_engine = Object.send(:remove_const, :RUBY_ENGINE)
    Object.const_set(:RUBY_ENGINE, "MyRuby")

    run_generator
    if /darwin|linux/.match?(RbConfig::CONFIG["host_os"])
      assert_listen_related_configuration
    else
      assert_no_listen_related_configuration
    end
  ensure
    Object.send(:remove_const, :RUBY_ENGINE)
    Object.const_set(:RUBY_ENGINE, ruby_engine)
  end

  def test_non_inclusion_of_listen_related_configuration_if_skip_listen
    run_generator [destination_root, "--skip-listen"]
    assert_no_listen_related_configuration
  end

  def test_evented_file_update_checker_config
    run_generator
    assert_file "config/environments/development.rb" do |content|
      if /darwin|linux/.match?(RbConfig::CONFIG["host_os"])
        assert_match(/^\s*config\.file_watcher = ActiveSupport::EventedFileUpdateChecker/, content)
      else
        assert_match(/^\s*# config\.file_watcher = ActiveSupport::EventedFileUpdateChecker/, content)
      end
    end
  end

  def test_template_from_dir_pwd
    FileUtils.cd(Rails.root)
    assert_match(/It works from file!/, run_generator([destination_root, "-m", "lib/template.rb"]))
  end

  def test_argv_is_populated_for_template
    FileUtils.cd(Rails.root)
    argv = [destination_root, "-m", "lib/template.rb"]

    assert_match %r/With ARGV! #{Regexp.escape argv.join(" ")}/, run_generator(argv)
  end

  def test_usage_read_from_file
    assert_called(File, :read, returns: "USAGE FROM FILE") do
      assert_equal "USAGE FROM FILE", Rails::Generators::AppGenerator.desc
    end
  end

  def test_default_usage
    assert_called(Rails::Generators::AppGenerator, :usage_path, returns: nil) do
      assert_match(/Create rails files for app generator/, Rails::Generators::AppGenerator.desc)
    end
  end

  def test_default_namespace
    assert_match "rails:app", Rails::Generators::AppGenerator.namespace
  end

  def test_file_is_added_for_backwards_compatibility
    action :file, "lib/test_file.rb", "heres test data"
    assert_file "lib/test_file.rb", "heres test data"
  end

  def test_pretend_option
    output = run_generator [File.join(destination_root, "myapp"), "--pretend"]
    assert_no_match(/run  bundle install/, output)
    assert_no_match(/run  git init/, output)
  end

  def test_quiet_option
    output = run_generator [File.join(destination_root, "myapp"), "--quiet"]
    assert_empty output
  end

  def test_force_option_overwrites_every_file_except_master_key
    run_generator [File.join(destination_root, "myapp")]
    output = run_generator [File.join(destination_root, "myapp"), "--force"]
    assert_match(/force/, output)
    assert_no_match("force  config/master.key", output)
  end

  def test_application_name_with_spaces
    path = File.join(destination_root, "foo bar")

    # This also applies to MySQL apps but not with SQLite
    run_generator [path, "-d", "postgresql"]

    assert_file "foo bar/config/database.yml", /database: foo_bar_development/
  end

  def test_web_console
    run_generator
    assert_gem "web-console"
  end

  def test_web_console_with_dev_option
    run_generator [destination_root, "--dev", "--skip-bundle"]

    assert_file "Gemfile" do |content|
      assert_match(/gem 'web-console',\s+github: 'rails\/web-console'/, content)
      assert_no_match(/\Agem 'web-console', '>= 4\.1\.0'\z/, content)
    end
  end

  def test_web_console_with_edge_option
    run_generator [destination_root, "--edge"]

    assert_file "Gemfile" do |content|
      assert_match(/gem 'web-console',\s+github: 'rails\/web-console'/, content)
      assert_no_match(/\Agem 'web-console', '>= 4\.1\.0'\z/, content)
    end
  end

  def test_web_console_with_master_option
    run_generator [destination_root, "--master"]

    assert_file "Gemfile" do |content|
      assert_match(/gem 'web-console',\s+github: 'rails\/web-console'/, content)
      assert_no_match(/\Agem 'web-console', '>= 4\.1\.0'\z/, content)
    end
  end

  def test_generation_runs_bundle_install
    generator([destination_root], skip_webpack_install: true)
    run_generator_instance

    assert_equal 1, @bundle_commands.count("install")
  end

  def test_generation_use_original_bundle_environment
    generator([destination_root], skip_webpack_install: true)

    mock_original_env = -> do
      { "BUNDLE_RUBYONRAILS__ORG" => "user:pass" }
    end

    ensure_environment_is_set = -> *_args do
      assert_equal "user:pass", ENV["BUNDLE_RUBYONRAILS__ORG"]
    end

    Bundler.stub :original_env, mock_original_env do
      generator.stub :exec_bundle_command, ensure_environment_is_set do
        quietly { generator.invoke_all }
      end
    end
  end

  def test_dev_option
    generator([destination_root], dev: true, skip_webpack_install: true)
    run_generator_instance

    assert_equal 1, @bundle_commands.count("install")
    rails_path = File.expand_path("../../..", Rails.root)
    assert_file "Gemfile", /^gem\s+["']rails["'],\s+path:\s+["']#{Regexp.escape(rails_path)}["']$/
  end

  def test_edge_option
    generator([destination_root], edge: true, skip_webpack_install: true)
    run_generator_instance

    assert_equal 1, @bundle_commands.count("install")
    assert_file "Gemfile", %r{^gem\s+["']rails["'],\s+github:\s+["']#{Regexp.escape("rails/rails")}["']$}
  end

  def test_master_option
    generator([destination_root], master: true, skip_webpack_install: true)
    run_generator_instance

    assert_equal 1, @bundle_commands.count("install")
    assert_file "Gemfile", %r{^gem\s+["']rails["'],\s+github:\s+["']#{Regexp.escape("rails/rails")}["'],\s+branch:\s+["']master["']$}
  end

  def test_spring
    jruby_skip "spring doesn't run on JRuby"

    run_generator

    assert_gem "spring"
    assert_file "bin/spring", %r{^\s*require "spring/binstub"}
    assert_file "bin/rails", %r{^\s*load .+"spring"}
    assert_file "bin/rake", %r{^\s*load .+"spring"}
    assert_file("config/environments/test.rb") do |contents|
      assert_match("config.cache_classes = false", contents)
      assert_match("config.action_view.cache_template_loading = true", contents)
    end
  end

  def test_bundler_binstub
    generator([destination_root], skip_webpack_install: true)
    run_generator_instance

    assert_equal 1, @bundle_commands.count("binstubs bundler")
  end

  def test_spring_no_fork
    respond_to = Process.method(:respond_to?)
    respond_to_stub = -> (name) { name != :fork && respond_to[name] }
    Process.stub(:respond_to?, respond_to_stub) do
      run_generator
    end

    assert_no_gem "spring"
  end

  def test_skip_spring
    run_generator [destination_root, "--skip-spring"]

    assert_no_file "config/spring.rb"
    assert_no_gem "spring"
    assert_file("config/environments/test.rb") do |contents|
      assert_match("config.cache_classes = true", contents)
    end
    assert_file "bin/rails" do |contents|
      assert_no_match %r{spring}, contents
    end
    assert_file "bin/rake" do |contents|
      assert_no_match %r{spring}, contents
    end
  end

  def test_spring_with_dev_option
    run_generator [destination_root, "--dev", "--skip-bundle"]

    assert_no_gem "spring"
  end

  def test_skip_active_record_option
    run_generator [destination_root, "--skip-active-record"]

    assert_file ".gitattributes" do |content|
      assert_no_match(/schema.rb/, content)
    end
  end

  def test_skip_javascript_option
    generator([destination_root], skip_javascript: true)

    command_check = -> command, *_ do
      if command == "webpacker:install"
        flunk "`webpacker:install` expected to not be called."
      end
    end

    generator.stub(:rails_command, command_check) do
      run_generator_instance
    end

    assert_no_gem "webpacker"

    assert_file "config/initializers/content_security_policy.rb" do |content|
      assert_no_match(/policy\.connect_src/, content)
    end

    assert_file ".gitattributes" do |content|
      assert_no_match(/yarn\.lock/, content)
    end
  end

  def test_webpack_option_with_js_framework
    generator([destination_root], webpack: "react")

    webpacker_called = 0
    react_called = 0
    command_check = -> command, *_ do
      case command
      when "webpacker:install"
        webpacker_called += 1
      when "webpacker:install:react"
        react_called += 1
      end
    end

    generator.stub(:rails_command, command_check) do
      run_generator_instance
    end

    assert_equal 1, webpacker_called, "`webpacker:install` expected to be called once, but was called #{webpacker_called} times."
    assert_equal 1, react_called, "`webpacker:install:react` expected to be called once, but was called #{react_called} times."
    assert_gem "webpacker"
  end

  def test_skip_webpack_install
    generator([destination_root], skip_webpack_install: true)

    command_check = -> command do
      if command == "webpacker:install"
        flunk "`webpacker:install` expected to not be called."
      end
    end

    generator.stub(:rails_command, command_check) do
      run_generator_instance
    end

    assert_gem "webpacker"
    assert_no_file "config/webpacker.yml"

    output = Dir.chdir(destination_root) do
      `bin/rails help`
    end

    assert_match(/The most common rails commands are:/, output)
    assert_match(/webpacker:install/, output)
    assert_equal true, $?.success?
  end

  def test_generator_if_skip_turbolinks_is_given
    run_generator [destination_root, "--skip-turbolinks"]

    assert_no_gem "turbolinks"
    assert_file "app/views/layouts/application.html.erb" do |content|
      assert_no_match(/data-turbolinks-track/, content)
    end
    assert_file "app/javascript/packs/application.js" do |content|
      assert_no_match(/turbolinks/, content)
    end
  end

  def test_bootsnap
    run_generator [destination_root, "--no-skip-bootsnap"]

    unless defined?(JRUBY_VERSION)
      assert_gem "bootsnap"
      assert_file "config/boot.rb" do |content|
        assert_match(/require "bootsnap\/setup"/, content)
      end
    else
      assert_no_gem "bootsnap"
      assert_file "config/boot.rb" do |content|
        assert_no_match(/require "bootsnap\/setup"/, content)
      end
    end
  end

  def test_skip_bootsnap
    run_generator [destination_root, "--skip-bootsnap"]

    assert_no_gem "bootsnap"
    assert_file "config/boot.rb" do |content|
      assert_no_match(/require "bootsnap\/setup"/, content)
    end
  end

  def test_bootsnap_with_dev_option
    run_generator [destination_root, "--dev", "--skip-bundle"]

    assert_no_gem "bootsnap"
    assert_file "config/boot.rb" do |content|
      assert_no_match(/require "bootsnap\/setup"/, content)
    end
  end

  def test_inclusion_of_ruby_version
    run_generator

    assert_file "Gemfile" do |content|
      assert_match(/ruby '#{RUBY_VERSION}'/, content)
    end
    assert_file ".ruby-version" do |content|
      if ENV["RBENV_VERSION"]
        assert_match(/#{ENV["RBENV_VERSION"]}/, content)
      elsif ENV["rvm_ruby_string"]
        assert_match(/#{ENV["rvm_ruby_string"]}/, content)
      else
        assert_match(/#{RUBY_ENGINE}-#{RUBY_ENGINE_VERSION}/, content)
      end

      assert content.end_with?("\n"), "expected .ruby-version to end with newline"
    end
  end

  def test_version_control_initializes_git_repo
    run_generator [destination_root]
    assert_directory ".git"
  end

  def test_default_branch_main_without_user_default
    current_default_branch = `git config --global init.defaultBranch`
    `git config --global --unset init.defaultBranch`

    run_generator [destination_root]
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

    run_generator [destination_root]
    assert_file ".git/HEAD", /master/
  ensure
    if current_default_branch && current_default_branch.strip.empty?
      `git config --global --unset init.defaultBranch`
    elsif current_default_branch
      `git config --global init.defaultBranch #{current_default_branch}`
    end
  end

  def test_create_keeps
    run_generator
    folders_with_keep = %w(
      app/assets/images
      app/controllers/concerns
      app/models/concerns
      lib/tasks
      lib/assets
      log
      test/fixtures/files
      test/controllers
      test/mailers
      test/models
      test/helpers
      test/integration
      tmp
      tmp/pids
    )
    folders_with_keep.each do |folder|
      assert_file("#{folder}/.keep")
    end
  end

  def test_psych_gem
    run_generator
    gem_regex = /gem 'psych',\s+'~> 2\.0',\s+platforms: :rbx/

    assert_file "Gemfile" do |content|
      if defined?(Rubinius)
        assert_match(gem_regex, content)
      else
        assert_no_match(gem_regex, content)
      end
    end
  end

  def test_principle_tasks_go_before_finish_template
    tasks = generator.class.tasks.keys

    assert_equal tasks.index("apply_rails_template") - 1, tasks.index("finish_template")
  end

  def test_after_bundle_callback
    generator([destination_root], skip_webpack_install: true).send(:after_bundle) do
      @bundle_commands_before_callback = @bundle_commands.dup
    end

    run_generator_instance

    assert_not_empty @bundle_commands_before_callback
    assert_equal @bundle_commands_before_callback, @bundle_commands
  end

  def test_gitignore
    run_generator

    assert_file ".gitignore" do |content|
      assert_match(/config\/master\.key/, content)
    end
  end

  def test_system_tests_directory_generated
    run_generator

    assert_directory("test/system")
    assert_file("test/system/.keep")
  end

  unless Gem.win_platform?
    def test_master_key_is_only_readable_by_the_owner
      run_generator

      stat = File.stat("config/master.key")
      assert_equal "100600", sprintf("%o", stat.mode)
    end
  end

  def test_minimal_rails_app
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root, "--minimal"]

    assert_no_file "#{app_root}/config/storage.yml"
    assert_no_file "#{app_root}/config/webpacker.yml"
    assert_no_file "#{app_root}/config/cable.yml"
    assert_no_file "#{app_root}/bin/yarn"
    assert_no_file "#{app_root}/views/layouts/mailer.html.erb"
    assert_no_file "#{app_root}/config/spring.rb"
    assert_no_file "#{app_root}/app/jobs/application.rb"
    assert_file "#{app_root}/app/views/layouts/application.html.erb" do |content|
      assert_no_match(/data-turbolinks-track/, content)
    end
    assert_file "#{app_root}/config/environments/development.rb" do |content|
      assert_no_match(/config\.active_storage/, content)
    end
    assert_file "#{app_root}/config/environments/production.rb" do |content|
      assert_no_match(/config\.active_job/, content)
    end
    assert_file "#{app_root}/config/boot.rb" do |content|
      assert_no_match(/require "bootsnap\/setup"/, content)
    end
    assert_file "#{app_root}/config/application.rb" do |content|
      assert_match(/#\s+require\s+["']active_job\/railtie["']/, content)
      assert_match(/#\s+require\s+["']active_storage\/engine["']/, content)
      assert_match(/#\s+require\s+["']action_mailer\/railtie["']/, content)
      assert_match(/#\s+require\s+["']action_mailbox\/engine["']/, content)
      assert_match(/#\s+require\s+["']action_text\/engine["']/, content)
      assert_match(/#\s+require\s+["']action_cable\/engine["']/, content)
      assert_match(/\s+require\s+["']sprockets\/railtie["']/, content)
    end

    assert_no_gem "webpacker", app_root
    assert_no_gem "jbuilder", app_root
    assert_no_gem "rack-mini-profiler", app_root
    assert_no_gem "spring", app_root
    assert_no_gem "web-console", app_root
  end

  private
    def stub_rails_application(root)
      Rails.application.config.root = root
      Rails.application.class.stub(:name, "Myapp") do
        yield
      end
    end

    def action(*args, &block)
      capture(:stdout) { generator.send(*args, &block) }
    end

    def assert_gem(gem, constraint = nil, app_path = ".")
      if constraint
        assert_file File.join(app_path, "Gemfile"), /^\s*gem\s+["']#{gem}["'], #{constraint}$*/
      else
        assert_file File.join(app_path, "Gemfile"), /^\s*gem\s+["']#{gem}["']$*/
      end
    end

    def assert_no_gem(gem, app_path = ".")
      assert_file File.join(app_path, "Gemfile") do |content|
        assert_no_match(gem, content)
      end
    end

    def assert_listen_related_configuration
      assert_gem "listen"

      assert_file "config/environments/development.rb" do |content|
        assert_match(/^\s*config\.file_watcher = ActiveSupport::EventedFileUpdateChecker/, content)
      end
    end

    def assert_no_listen_related_configuration
      assert_no_gem "listen"

      assert_file "config/environments/development.rb" do |content|
        assert_match(/^\s*# config\.file_watcher = ActiveSupport::EventedFileUpdateChecker/, content)
      end
    end
end
