# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/app/app_generator"
require "generators/shared_generator_tests"

DEFAULT_APP_FILES = %w(
  .gitattributes
  .gitignore
  .dockerignore
  .ruby-version
  README.md
  Gemfile
  Rakefile
  Dockerfile
  config.ru
  app/assets/config/manifest.js
  app/assets/images
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
  bin/docker-entrypoint
  bin/rails
  bin/rake
  bin/setup
  config/application.rb
  config/boot.rb
  config/cable.yml
  config/environment.rb
  config/environments
  config/environments/development.rb
  config/environments/production.rb
  config/environments/test.rb
  config/initializers
  config/initializers/assets.rb
  config/initializers/content_security_policy.rb
  config/initializers/filter_parameter_logging.rb
  config/initializers/inflections.rb
  config/locales
  config/locales/en.yml
  config/puma.rb
  config/routes.rb
  config/credentials.yml.enc
  config/storage.yml
  db
  db/seeds.rb
  lib
  lib/tasks
  lib/assets
  log
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
    generator([destination_root], skip_bundle: true)
    run_generator_instance

    assert_empty @bundle_commands
    # skip_bundle is only about running bundle install so ensure the Gemfile is still generated
    assert_file "Gemfile"
  end

  def test_assets
    run_generator

    assert_file("app/assets/stylesheets/application.css")
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
    quietly { system "#{File.expand_path("../../exe/rails", __dir__)} new test --no-rc" }
    assert_equal false, $?.success?
  end

  def test_application_new_exits_with_message_and_non_zero_code_when_generating_inside_existing_rails_directory
    run_generator
    output = nil
    Dir.chdir(destination_root) do
      output = `#{File.expand_path("../../exe/rails", __dir__)} new mysecondapp`
    end
    assert_equal "Can't initialize a new Rails application within the directory of another, please change to a non-Rails directory first.\nType 'rails' for help.\n", output
    assert_equal false, $?.success?
  end

  def test_application_new_show_help_message_inside_existing_rails_directory
    run_generator
    output = Dir.chdir(destination_root) do
      `#{File.expand_path("../../exe/rails", __dir__)} new --help`
    end
    assert_match(/rails new APP_PATH \[options\]/, output)
    assert_equal true, $?.success?
  end

  def test_application_name_is_detected_if_it_exists_and_app_folder_renamed
    app_root       = File.join(destination_root, "myapp")
    app_moved_root = File.join(destination_root, "myapp_moved")

    run_generator [app_root]
    FileUtils.mv(app_root, app_moved_root)
    run_app_update(app_moved_root)

    assert_file "#{app_moved_root}/config/environment.rb", /Rails\.application\.initialize!/
  end

  def test_new_application_not_include_api_initializers
    run_generator

    assert_no_file "config/initializers/cors.rb"
  end

  def test_new_application_doesnt_need_defaults
    run_generator
    assert_empty Dir.glob("config/initializers/new_framework_defaults_*.rb", base: destination_root)
  end

  def test_new_application_load_defaults
    run_generator
    assert_file "config/application.rb", /\s+config\.load_defaults #{Rails::VERSION::STRING.to_f}/
  end

  def test_app_update_create_new_framework_defaults
    defaults_path = "config/initializers/new_framework_defaults_#{Rails::VERSION::MAJOR}_#{Rails::VERSION::MINOR}.rb"

    run_generator
    assert_no_file defaults_path

    run_app_update
    assert_file defaults_path
  end

  def test_app_update_does_not_create_rack_cors
    run_generator
    run_app_update

    assert_no_file "config/initializers/cors.rb"
  end

  def test_app_update_does_not_remove_rack_cors_if_already_present
    run_generator
    FileUtils.touch("#{destination_root}/config/initializers/cors.rb")
    run_app_update

    assert_file "config/initializers/cors.rb"
  end

  def test_app_update_does_not_generate_assets_initializer_when_sprockets_and_propshaft_are_not_used
    run_generator [destination_root, "-a", "none"]
    run_app_update

    assert_no_file "config/initializers/assets.rb"
    assert_no_file "app/assets/config/manifest.js"
  end

  def test_app_update_does_not_generate_manifest_config_when_propshaft_is_used
    run_generator [destination_root, "-a", "propshaft"]
    run_app_update

    assert_file "config/initializers/assets.rb"
    assert_no_file "app/assets/config/manifest.js"
  end

  def test_app_update_does_not_generate_action_cable_contents_when_skip_action_cable_is_given
    run_generator [destination_root, "--skip-action-cable"]
    run_app_update

    assert_no_file "config/cable.yml"
    assert_file "config/environments/production.rb" do |content|
      assert_no_match(/config\.action_cable/, content)
    end
    assert_no_file "test/channels/application_cable/connection_test.rb"
  end

  def test_app_update_does_not_generate_bootsnap_contents_when_skip_bootsnap_is_given
    run_generator [destination_root, "--skip-bootsnap"]
    run_app_update

    assert_file "config/boot.rb" do |content|
      assert_no_match(/require "bootsnap\/setup"/, content)
    end
  end

  def test_app_update_preserves_skip_active_job
    run_generator [ destination_root, "--skip-active-job" ]

    FileUtils.cd(destination_root) do
      config = "config/application.rb"
      assert_no_changes -> { File.readlines(config).grep(/require /) } do
        run_app_update
      end
    end
  end

  def test_app_update_preserves_skip_action_mailbox
    run_generator [ destination_root, "--skip-action-mailbox" ]

    FileUtils.cd(destination_root) do
      config = "config/application.rb"
      assert_no_changes -> { File.readlines(config).grep(/require /) } do
        run_app_update
      end
    end
  end

  def test_app_update_preserves_skip_action_text
    run_generator [ destination_root, "--skip-action-text" ]

    FileUtils.cd(destination_root) do
      config = "config/application.rb"
      assert_no_changes -> { File.readlines(config).grep(/require /) } do
        run_app_update
      end
    end
  end

  def test_app_update_preserves_skip_test
    run_generator [ destination_root, "--skip-test" ]

    FileUtils.cd(destination_root) do
      config = "config/application.rb"
      assert_no_changes -> { File.readlines(config).grep(/require /) } do
        run_app_update
      end
    end
  end

  def test_app_update_preserves_skip_system_test
    run_generator [ destination_root, "--skip-system-test" ]

    FileUtils.cd(destination_root) do
      config = "config/application.rb"
      assert_file config, /generators\.system_tests/
      assert_no_changes -> { File.readlines(config).grep(/generators\.system_tests/) } do
        run_app_update
      end
    end
  end

  def test_gem_for_active_storage
    run_generator
    assert_file "Gemfile", /^# gem "image_processing"/
  end

  def test_gem_for_active_storage_when_skip_active_storage_is_given
    run_generator [destination_root, "--skip-active-storage"]

    assert_no_gem "image_processing"

    assert_file "Dockerfile" do |content|
      assert_no_match(/libvips/, content)
    end
  end

  def test_app_update_does_not_generate_active_storage_contents_when_skip_active_storage_is_given
    run_generator [destination_root, "--skip-active-storage"]
    run_app_update

    assert_file "config/environments/development.rb" do |content|
      assert_no_match(/config\.active_storage/, content)
    end

    assert_file "config/environments/production.rb" do |content|
      assert_no_match(/config\.active_storage/, content)
    end

    assert_file "config/environments/test.rb" do |content|
      assert_no_match(/config\.active_storage/, content)
    end

    assert_no_file "config/storage.yml"
  end

  def test_app_update_does_not_generate_active_storage_contents_when_skip_active_record_is_given
    run_generator [destination_root, "--skip-active-record"]
    run_app_update

    assert_file "config/environments/development.rb" do |content|
      assert_no_match(/config\.active_storage/, content)
    end

    assert_file "config/environments/production.rb" do |content|
      assert_no_match(/config\.active_storage/, content)
    end

    assert_file "config/environments/test.rb" do |content|
      assert_no_match(/config\.active_storage/, content)
    end

    assert_no_file "config/storage.yml"
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
    run_generator

    FileUtils.cd(destination_root) do
      config = "config/application.rb"
      content = File.read(config)
      File.write(config, content.gsub(/config\.load_defaults #{Rails::VERSION::STRING.to_f}/, "config.load_defaults 5.1"))
    end

    run_app_update

    assert_file "config/application.rb", /\s+config\.load_defaults 5\.1/
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

    run_app_update(app_root)

    assert_file "#{app_root}/config/cable.yml" do |content|
      assert_match(/hyphenated_app/, content)
      assert_no_match(/hyphenated-app/, content)
    end
  end

  def test_application_names_are_not_singularized
    run_generator [File.join(destination_root, "hats")]
    assert_file "hats/config/environment.rb", /Rails\.application\.initialize!/
  end

  def test_application_name_is_normalized_in_config
    run_generator [File.join(destination_root, "MyWebSite"), "-d", "postgresql"]
    assert_file "MyWebSite/app/views/layouts/application.html.erb", /<title>MyWebSite<\/title>/
    assert_file "MyWebSite/config/database.yml", /my_web_site_production/
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
      assert_gem "sqlite3", '"~> 1.4"'
    end
  end

  def test_config_mysql_database
    run_generator([destination_root, "-d", "mysql"])
    assert_file "config/database.yml", /mysql/
    if defined?(JRUBY_VERSION)
      assert_gem "activerecord-jdbcmysql-adapter"
    else
      assert_gem "mysql2", '"~> 0.5"'
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
      assert_gem "pg", '"~> 1.1"'
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
    assert_gem "puma", /"\W+ \d/
  end

  def test_action_cable_redis_gems
    run_generator
    assert_file "Gemfile", /^# gem "redis"/
  end

  def test_generator_configures_decrypted_diffs_by_default
    run_generator
    assert_file ".gitattributes", /\.enc diff=/
  end

  def test_generator_does_not_configure_decrypted_diffs_when_skip_decrypted_diffs_is_given
    run_generator [destination_root, "--skip-decrypted-diffs"]
    assert_file ".gitattributes" do |content|
      assert_no_match %r/\.enc diff=/, content
    end
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
    assert_no_file "app/jobs/application_job.rb"
    assert_file "config/environments/production.rb" do |content|
      assert_no_match(/config\.active_job/, content)
    end
    assert_file "config/application.rb" do |content|
      assert_match(/#\s+require\s+["']active_job\/railtie["']/, content)
      assert_match(/#\s+require\s+["']active_storage\/engine["']/, content)
      assert_match(/#\s+require\s+["']action_mailer\/railtie["']/, content)
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

  def test_viewport_meta_tag_is_present
    run_generator [destination_root]

    assert_file "app/views/layouts/application.html.erb" do |contents|
      assert_match(/<meta name="viewport"/, contents)
    end
  end

  def test_javascript_is_skipped_if_required
    run_generator [destination_root, "--skip-javascript"]

    assert_no_file "app/javascript"

    assert_file "app/views/layouts/application.html.erb" do |contents|
      assert_match(/stylesheet_link_tag\s+"application" %>/, contents)
    end
  end

  def test_inclusion_of_jbuilder
    run_generator
    assert_gem "jbuilder"
  end

  def test_inclusion_of_a_debugger
    run_generator
    if defined?(JRUBY_VERSION)
      assert_no_gem "debug"
    else
      assert_gem "debug"
    end
  end

  def test_template_from_dir_pwd
    FileUtils.cd(Rails.root)
    assert_match(/It works from file!/, run_generator([destination_root, "-m", "lib/template.rb"]))
  end

  def test_template_from_url
    url = "https://raw.githubusercontent.com/rails/rails/f95c0b7e96/railties/test/fixtures/lib/template.rb"
    FileUtils.cd(Rails.root)
    assert_match(/It works from file!/, run_generator([destination_root, "-m", url]))
  end

  def test_template_from_abs_path
    absolute_path = File.expand_path(Rails.root, "fixtures")
    FileUtils.cd(Rails.root)
    assert_match(/It works from file!/, run_generator([destination_root, "-m", "#{absolute_path}/lib/template.rb"]))
  end

  def test_template_from_env_var_path
    ENV["FIXTURES_HOME"] = File.expand_path(Rails.root, "fixtures")
    FileUtils.cd(Rails.root)
    assert_match(/It works from file!/, run_generator([destination_root, "-m", "$FIXTURES_HOME/lib/template.rb"]))
    ENV.delete("FIXTURES_HOME")
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
    action :file, "lib/test_file.rb", "here's test data"
    assert_file "lib/test_file.rb", "here's test data"
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

  def test_generation_runs_bundle_install
    generator([destination_root])
    run_generator_instance

    assert_equal 1, @bundle_commands.count("install")
  end

  def test_generation_use_original_bundle_environment
    generator([destination_root])

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

  def test_bundler_binstub
    generator([destination_root])
    run_generator_instance

    assert_equal 1, @bundle_commands.count("binstubs bundler")
  end

  def test_skip_active_record_option
    run_generator [destination_root, "--skip-active-record"]

    assert_file ".gitattributes" do |content|
      assert_no_match(/schema.rb/, content)
    end
  end

  def test_skip_active_job_option
    run_generator [destination_root, "--skip-active-job"]

    ["production", "development", "test"].each do |env|
      assert_file "config/environments/#{env}.rb" do |content|
        assert_no_match(/active_job/, content)
      end
    end
  end

  def test_skip_javascript_option
    generator([destination_root], skip_javascript: true)

    command_check = -> command, *_ do
      if command == "importmap:install"
        flunk "`importmap:install` expected to not be called."
      end
    end

    generator.stub(:rails_command, command_check) do
      run_generator_instance
    end

    assert_no_gem "importmap-rails"

    assert_file "config/initializers/content_security_policy.rb" do |content|
      assert_no_match(/policy\.connect_src/, content)
    end

    assert_file ".gitattributes" do |content|
      assert_no_match(/yarn\.lock/, content)
    end

    assert_no_file ".node-version"
  end

  def test_webpack_option
    generator([destination_root], javascript: "webpack")

    webpacker_called = 0
    command_check = -> command, *_ do
      case command
      when "javascript:install:webpack"
        webpacker_called += 1
      end
    end

    generator.stub(:rails_command, command_check) do
      run_generator_instance
    end

    assert_equal 1, webpacker_called, "`javascript:install:webpack` expected to be called once, but was called #{webpacker_called} times."
    assert_gem "jsbundling-rails"

    assert_file "Dockerfile" do |content|
      assert_match(/yarn/, content)
      assert_match(/node-gyp/, content)
    end

    assert_file ".node-version" do |content|
      if ENV["NODE_VERSION"]
        assert_match(/#{ENV["NODE_VERSION"]}/, content)
      else
        assert_match(/\d+\.\d+\.\d+/, content)
      end
    end
  end

  def test_esbuild_option
    generator([destination_root], javascript: "esbuild")

    esbuild_called = 0
    command_check = -> command, *_ do
      case command
      when "javascript:install:esbuild"
        esbuild_called += 1
      end
    end

    generator.stub(:rails_command, command_check) do
      run_generator_instance
    end

    assert_equal 1, esbuild_called, "`javascript:install:esbuild` expected to be called once, but was called #{esbuild_called} times."
    assert_gem "jsbundling-rails"
  end

  def test_esbuild_option_with_javacript_argument
    run_generator [destination_root, "--javascript", "esbuild"]
    assert_gem "jsbundling-rails"
  end

  def test_esbuild_option_with_j_argument
    run_generator [destination_root, "-j", "esbuild"]
    assert_gem "jsbundling-rails"
  end

  def test_esbuild_option_with_js_argument
    run_generator [destination_root, "--js", "esbuild"]
    assert_gem "jsbundling-rails"
  end

  def test_skip_javascript_option_with_skip_javascript_argument
    run_generator [destination_root, "--skip-javascript"]
    assert_no_gem "stimulus-rails"
    assert_no_gem "turbo-rails"
    assert_no_gem "importmap-rails"
  end

  def test_skip_javascript_option_with_J_argument
    run_generator [destination_root, "-J"]
    assert_no_gem "stimulus-rails"
    assert_no_gem "turbo-rails"
    assert_no_gem "importmap-rails"
  end

  def test_skip_javascript_option_with_skip_js_argument
    run_generator [destination_root, "--skip-js"]
    assert_no_gem "stimulus-rails"
    assert_no_gem "turbo-rails"
    assert_no_gem "importmap-rails"
  end

  def test_no_skip_javascript_option_with_no_skip_javascript_argument
    run_generator [destination_root, "--no-skip-javascript"]
    assert_gem "stimulus-rails"
    assert_gem "turbo-rails"
    assert_gem "importmap-rails"
  end

  def test_hotwire
    run_generator_and_bundler [destination_root]
    assert_gem "turbo-rails"
    assert_gem "stimulus-rails"
    assert_file "app/views/layouts/application.html.erb" do |content|
      assert_match(/data-turbo-track/, content)
    end
    assert_file "app/javascript/application.js" do |content|
      assert_match(/turbo/, content)
      assert_match(/controllers/, content)
    end
  end

  def test_skip_hotwire
    run_generator [destination_root, "--skip-hotwire"]

    assert_no_gem "turbo-rails"
    assert_file "app/views/layouts/application.html.erb" do |content|
      assert_no_match(/data-turbo-track/, content)
    end
    assert_no_file "app/javascript/application.js"
  end

  def test_css_option_with_asset_pipeline_tailwind
    run_generator_and_bundler [destination_root, "--css=tailwind"]
    assert_gem "tailwindcss-rails"
    assert_file "app/views/layouts/application.html.erb" do |content|
      assert_match(/tailwind/, content)
    end
  end

  def test_css_option_with_asset_pipeline_sass
    run_generator_and_bundler [destination_root, "--css=sass"]
    assert_gem "dartsass-rails"
    assert_file "app/assets/stylesheets/application.scss"
  end

  def test_css_option_with_cssbundling_gem
    run_generator_and_bundler [destination_root, "--css=postcss"]
    assert_gem "cssbundling-rails"
    assert_file "app/assets/stylesheets/application.postcss.css"
  end

  def test_dev_gems
    run_generator [destination_root, "--no-skip-dev-gems"]
    assert_gem "web-console"
  end

  def test_skip_dev_gems
    run_generator [destination_root, "--skip-dev-gems"]
    assert_no_gem "web-console"
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
    run_generator_using_prerelease [destination_root, "--dev"]

    assert_no_gem "bootsnap"
    assert_file "config/boot.rb" do |content|
      assert_no_match(/require "bootsnap\/setup"/, content)
    end
  end

  def test_inclusion_of_ruby_version
    run_generator

    assert_file "Gemfile" do |content|
      assert_match(/ruby "#{Gem::Version.new(Gem::VERSION) >= Gem::Version.new("3.3.13") ? Gem.ruby_version : RUBY_VERSION}"/, content)
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

  def test_principle_tasks_go_before_finish_template
    tasks = generator.class.tasks.keys

    assert_equal tasks.index("apply_rails_template") - 1, tasks.index("finish_template")
  end

  def test_after_bundle_callback
    generator([destination_root]).send(:after_bundle) do
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

  def test_dockerignore
    run_generator

    assert_file ".dockerignore" do |content|
      assert_match(/config\/master\.key/, content)
    end
  end

  def test_dockerfile
    run_generator

    assert_file "Dockerfile" do |content|
      assert_match(/assets:precompile/, content)
      assert_match(/libvips/, content)
      assert_no_match(/yarn/, content)
      assert_no_match(/node-gyp/, content)
    end
  end

  def test_old_rubies_do_not_use_bullseye_python
    Gem.stub(:ruby_version, Gem::Version.new("2.7.0")) do
      run_generator [destination_root, "--js=esbuild"]
    end

    assert_file "Dockerfile" do |content|
      assert_match(/python/, content)
      assert_no_match(/python-is-python3/, content)
    end
  end

  def test_skip_docker
    run_generator [destination_root, "--skip-docker"]

    assert_no_file ".dockerignore"
    assert_no_file "Dockerfile"
    assert_no_file "bin/docker-entrypoint"
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
    generator([destination_root], ["--minimal"])

    assert_option :minimal
    assert_option :skip_action_cable
    assert_option :skip_action_mailbox
    assert_option :skip_action_mailer
    assert_option :skip_action_text
    assert_option :skip_active_job
    assert_option :skip_active_storage
    assert_option :skip_bootsnap
    assert_option :skip_dev_gems
    assert_option :skip_hotwire
    assert_option :skip_javascript
    assert_option :skip_jbuilder
    assert_option :skip_system_test
  end

  def test_minimal_rails_app_with_no_skip_implied_option
    generator([destination_root], ["--minimal", "--no-skip-action-text"])

    assert_not_option :skip_action_text
    assert_not_option :skip_active_storage
    assert_not_option :skip_active_job
    assert_option :skip_action_mailbox
    assert_option :skip_action_mailer
    assert_option :minimal
  end

  def test_minimal_rails_app_with_no_skip_intermediary_implied_option
    generator([destination_root], ["--minimal", "--no-skip-active-storage"])

    assert_not_option :skip_active_storage
    assert_not_option :skip_active_job
    assert_option :skip_action_text
    assert_option :skip_action_mailbox
    assert_option :skip_action_mailer
    assert_option :minimal
  end

  def test_name_option
    run_generator [destination_root, "--name=my-app"]
    assert_file "config/application.rb", /^module MyApp$/
  end

  private
    def run_generator_and_bundler(args)
      option_args, positional_args = args.partition { |arg| arg.start_with?("--") }
      option_args << "--no-skip-bundle"
      generator(positional_args, option_args)

      # Stub `rails_gemfile_entry` so that Bundler resolves `gem "rails"` to the
      # current repository instead of searching for an invalid version number
      # (for a version that hasn't been released yet).
      rails_gemfile_entry = Rails::Generators::AppBase::GemfileEntry.path("rails", Rails::Generators::RAILS_DEV_PATH)
      generator.stub(:rails_gemfile_entry, -> { rails_gemfile_entry }) do
        quietly { run_generator_instance }
      end
    end

    def run_app_update(app_root = destination_root)
      Dir.chdir(app_root) do
        gemfile_contents = File.read("Gemfile")
        gemfile_contents.sub!(/^(gem "rails").*/, "\\1, path: #{File.expand_path("../../..", __dir__).inspect}")
        File.write("Gemfile", gemfile_contents)

        quietly { system({ "BUNDLE_GEMFILE" => "Gemfile" }, "yes | bin/rails app:update", exception: true) }
      end
    end

    def action(*args, &block)
      capture(:stdout) { generator.send(*args, &block) }
    end
end
