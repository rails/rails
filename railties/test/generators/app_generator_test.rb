# frozen_string_literal: true

require "generators/generators_test_helper"
require "generators/shared_generator_tests"
require "rails/generators/rails/app/app_generator"
require "rails/app_updater"

DEFAULT_APP_FILES = %w(
  .gitignore
  .ruby-version
  README.md
  Gemfile
  Rakefile
  config.ru
  app/assets/config/manifest.js
  app/assets/images
  app/assets/javascripts
  app/assets/javascripts/application.js
  app/assets/javascripts/cable.js
  app/assets/javascripts/channels
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
  bin/bundle
  bin/rails
  bin/rake
  bin/setup
  bin/update
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
    assert_not_called(generator([destination_root], skip_bundle: true), :bundle_command) do
      quietly { generator.invoke_all }
      # skip_bundle is only about running bundle install, ensure the Gemfile is still
      # generated.
      assert_file "Gemfile"
    end
  end

  def test_assets
    run_generator

    assert_file("app/views/layouts/application.html.erb", /stylesheet_link_tag\s+'application', media: 'all', 'data-turbolinks-track': 'reload'/)
    assert_file("app/views/layouts/application.html.erb", /javascript_include_tag\s+'application', 'data-turbolinks-track': 'reload'/)
    assert_file("app/assets/stylesheets/application.css")
    assert_file("app/assets/javascripts/application.js")
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
        quietly { generator.send(:update_config_files) }
        assert_file "myapp_moved/config/environment.rb", /Rails\.application\.initialize!/
      end
    end
  end

  def test_app_update_generates_correct_session_key
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.send(:update_config_files) }
    end
  end

  def test_new_application_use_json_serialzier
    run_generator

    assert_file("config/initializers/cookies_serializer.rb", /Rails\.application\.config\.action_dispatch\.cookies_serializer = :json/)
  end

  def test_new_application_not_include_api_initializers
    run_generator

    assert_no_file "config/initializers/cors.rb"
  end

  def test_new_application_doesnt_need_defaults
    assert_no_file "config/initializers/new_framework_defaults_5_2.rb"
  end

  def test_new_application_load_defaults
    app_root = File.join(destination_root, "myfirstapp")
    run_generator [app_root]
    output = nil

    assert_file "#{app_root}/config/application.rb", /\s+config\.load_defaults #{Rails::VERSION::STRING.to_f}/

    Dir.chdir(app_root) do
      output = `./bin/rails r "puts Rails.application.config.assets.unknown_asset_fallback"`
    end

    assert_equal "false\n", output
  end

  def test_app_update_keep_the_cookie_serializer_if_it_is_already_configured
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.send(:update_config_files) }
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
      quietly { generator.send(:update_config_files) }
      assert_file("#{app_root}/config/initializers/cookies_serializer.rb",
                  /Valid options are :json, :marshal, and :hybrid\.\nRails\.application\.config\.action_dispatch\.cookies_serializer = :marshal/)
    end
  end

  def test_app_update_create_new_framework_defaults
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root]

    assert_no_file "#{app_root}/config/initializers/new_framework_defaults_5_2.rb"

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], { update: true }, { destination_root: app_root, shell: @shell }
      generator.send(:app_const)
      quietly { generator.send(:update_config_files) }

      assert_file "#{app_root}/config/initializers/new_framework_defaults_5_2.rb"
    end
  end

  def test_app_update_does_not_create_rack_cors
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.send(:update_config_files) }
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
      quietly { generator.send(:update_config_files) }
      assert_file "#{app_root}/config/initializers/cors.rb"
    end
  end

  def test_app_update_does_not_generate_assets_initializer_when_skip_sprockets_is_given
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root, "--skip-sprockets"]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], { update: true, skip_sprockets: true }, { destination_root: app_root, shell: @shell }
      generator.send(:app_const)
      quietly { generator.send(:update_config_files) }

      assert_no_file "#{app_root}/config/initializers/assets.rb"
    end
  end

  def test_app_update_does_not_generate_action_cable_contents_when_skip_action_cable_is_given
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root, "--skip-action-cable"]

    FileUtils.cd(app_root) do
      quietly { system("bin/rails app:update") }
    end

    assert_no_file "#{app_root}/config/cable.yml"
    assert_file "#{app_root}/config/environments/production.rb" do |content|
      assert_no_match(/config\.action_cable/, content)
    end
  end

  def test_active_storage_mini_magick_gem
    run_generator
    assert_file "Gemfile", /^# gem 'mini_magick'/
  end

  def test_app_update_generate_active_storage_contents_when_active_storage_does_not_defined
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root, "--skip-active-storage"]

    gen = Rails::AppUpdater.app_generator
    gen.shell = @shell
    gen.destination_root = app_root

    quietly { gen.update_config_files }

    assert_file "#{app_root}/config/environments/development.rb" do |content|
      assert_match(/config\.active_storage/, content)
    end

    assert_file "#{app_root}/config/environments/production.rb" do |content|
      assert_match(/config\.active_storage/, content)
    end

    assert_file "#{app_root}/config/environments/test.rb" do |content|
      assert_match(/config\.active_storage/, content)
    end

    assert_file "#{app_root}/config/storage.yml"
  end

  def test_app_update_does_not_generate_active_storage_contents_when_skip_active_record_is_given
    app_root = File.join(destination_root, "myapp")
    run_generator [app_root, "--skip-active-record"]

    FileUtils.cd(app_root) do
      quietly { system("bin/rails app:update") }
    end

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

    assert_file "#{app_root}/Gemfile" do |content|
      assert_no_match(/gem 'mini_magick'/, content)
    end
  end

  def test_app_update_does_not_change_config_target_version
    run_generator

    FileUtils.cd(destination_root) do
      config = "config/application.rb"
      content = File.read(config)
      File.write(config, content.gsub(/config\.load_defaults #{Rails::VERSION::STRING.to_f}/, "config.load_defaults 5.1"))
      quietly { system("bin/rails app:update") }
    end

    assert_file "config/application.rb", /\s+config\.load_defaults 5\.1/
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
      assert_gem "sqlite3"
    end
  end

  def test_config_mysql_database
    run_generator([destination_root, "-d", "mysql"])
    assert_file "config/database.yml", /mysql/
    if defined?(JRUBY_VERSION)
      assert_gem "activerecord-jdbcmysql-adapter"
    else
      assert_gem "mysql2", "'>= 0.4.4', '< 0.6.0'"
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
      assert_gem "pg", "'>= 0.18', '< 2.0'"
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
    assert_gem "puma", "'~> 3.11'"
  end

  def test_generator_if_skip_puma_is_given
    run_generator [destination_root, "--skip-puma"]
    assert_no_file "config/puma.rb"
    assert_file "Gemfile" do |content|
      assert_no_match(/puma/, content)
    end
  end

  def test_generator_has_assets_gems
    run_generator

    assert_gem "sass-rails"
    assert_gem "uglifier"
  end

  def test_action_cable_redis_gems
    run_generator
    assert_file "Gemfile", /^# gem 'redis'/
  end

  def test_generator_if_skip_test_is_given
    run_generator [destination_root, "--skip-test"]

    assert_file "config/application.rb", /#\s+require\s+["']rails\/test_unit\/railtie["']/

    assert_file "Gemfile" do |content|
      assert_no_match(/capybara/, content)
      assert_no_match(/selenium-webdriver/, content)
      assert_no_match(/chromedriver-helper/, content)
    end

    assert_no_directory("test")
  end

  def test_generator_if_skip_system_test_is_given
    run_generator [destination_root, "--skip-system-test"]
    assert_file "Gemfile" do |content|
      assert_no_match(/capybara/, content)
      assert_no_match(/selenium-webdriver/, content)
      assert_no_match(/chromedriver-helper/, content)
    end

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

  def test_inclusion_of_javascript_runtime
    run_generator
    if defined?(JRUBY_VERSION)
      assert_gem "therubyrhino"
    elsif RUBY_PLATFORM =~ /mingw|mswin/
      assert_gem "duktape"
    else
      assert_file "Gemfile", /# gem 'mini_racer', platforms: :ruby/
    end
  end

  def test_rails_ujs_is_the_default_ujs_library
    run_generator
    assert_file "app/assets/javascripts/application.js" do |contents|
      assert_match %r{^//= require rails-ujs}, contents
    end
  end

  def test_javascript_is_skipped_if_required
    run_generator [destination_root, "--skip-javascript"]

    assert_no_file "app/assets/javascripts"

    assert_file "app/views/layouts/application.html.erb" do |contents|
      assert_match(/stylesheet_link_tag\s+'application', media: 'all' %>/, contents)
      assert_no_match(/javascript_include_tag\s+'application' \%>/, contents)
    end

    assert_file "Gemfile" do |content|
      assert_no_match(/coffee-rails/, content)
      assert_no_match(/uglifier/, content)
    end

    assert_file "config/environments/production.rb" do |content|
      assert_no_match(/config\.assets\.js_compressor = :uglifier/, content)
    end
  end

  def test_coffeescript_is_skipped_if_required
    run_generator [destination_root, "--skip-coffee"]

    assert_file "Gemfile" do |content|
      assert_no_match(/coffee-rails/, content)
      assert_match(/uglifier/, content)
    end
  end

  def test_inclusion_of_jbuilder
    run_generator
    assert_gem "jbuilder"
  end

  def test_inclusion_of_a_debugger
    run_generator
    if defined?(JRUBY_VERSION) || RUBY_ENGINE == "rbx"
      assert_file "Gemfile" do |content|
        assert_no_match(/byebug/, content)
      end
    else
      assert_gem "byebug"
    end
  end

  def test_inclusion_of_listen_related_configuration_by_default
    run_generator
    if RbConfig::CONFIG["host_os"] =~ /darwin|linux/
      assert_listen_related_configuration
    else
      assert_no_listen_related_configuration
    end
  end

  def test_non_inclusion_of_listen_related_configuration_if_skip_listen
    run_generator [destination_root, "--skip-listen"]
    assert_no_listen_related_configuration
  end

  def test_evented_file_update_checker_config
    run_generator
    assert_file "config/environments/development.rb" do |content|
      if RbConfig::CONFIG["host_os"] =~ /darwin|linux/
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
    run_generator [destination_root, "--dev"]

    assert_file "Gemfile" do |content|
      assert_match(/gem 'web-console',\s+github: 'rails\/web-console'/, content)
      assert_no_match(/\Agem 'web-console', '>= 3\.3\.0'\z/, content)
    end
  end

  def test_web_console_with_edge_option
    run_generator [destination_root, "--edge"]

    assert_file "Gemfile" do |content|
      assert_match(/gem 'web-console',\s+github: 'rails\/web-console'/, content)
      assert_no_match(/\Agem 'web-console', '>= 3\.3\.0'\z/, content)
    end
  end

  def test_generation_runs_bundle_install
    assert_generates_with_bundler
  end

  def test_dev_option
    assert_generates_with_bundler dev: true
    rails_path = File.expand_path("../../..", Rails.root)
    assert_file "Gemfile", /^gem\s+["']rails["'],\s+path:\s+["']#{Regexp.escape(rails_path)}["']$/
  end

  def test_edge_option
    assert_generates_with_bundler edge: true
    assert_file "Gemfile", %r{^gem\s+["']rails["'],\s+github:\s+["']#{Regexp.escape("rails/rails")}["'],\s+branch:\s+["']#{Regexp.escape("5-2-stable")}["']$}
  end

  def test_spring
    run_generator
    assert_gem "spring"
  end

  def test_spring_binstubs
    jruby_skip "spring doesn't run on JRuby"
    command_check = -> command do
      @binstub_called ||= 0

      case command
      when "install"
        # Called when running bundle, we just want to stub it so nothing to do here.
      when "exec spring binstub --all"
        @binstub_called += 1
        assert_equal 1, @binstub_called, "exec spring binstub --all expected to be called once, but was called #{@install_called} times."
      end
    end

    generator.stub :bundle_command, command_check do
      quietly { generator.invoke_all }
    end
  end

  def test_spring_no_fork
    jruby_skip "spring doesn't run on JRuby"
    assert_called_with(Process, :respond_to?, [[:fork], [:fork]], returns: false) do
      run_generator

      assert_file "Gemfile" do |content|
        assert_no_match(/spring/, content)
      end
    end
  end

  def test_skip_spring
    run_generator [destination_root, "--skip-spring"]

    assert_no_file "config/spring.rb"
    assert_file "Gemfile" do |content|
      assert_no_match(/spring/, content)
    end
  end

  def test_spring_with_dev_option
    run_generator [destination_root, "--dev"]

    assert_file "Gemfile" do |content|
      assert_no_match(/spring/, content)
    end
  end

  def test_webpack_option
    command_check = -> command, *_ do
      @called ||= 0
      if command == "webpacker:install"
        @called += 1
        assert_equal 1, @called, "webpacker:install expected to be called once, but was called #{@called} times."
      end
    end

    generator([destination_root], webpack: "webpack").stub(:rails_command, command_check) do
      generator.stub :bundle_command, nil do
        quietly { generator.invoke_all }
      end
    end

    assert_gem "webpacker"
  end

  def test_webpack_option_with_js_framework
    command_check = -> command, *_ do
      case command
      when "webpacker:install"
        @webpacker ||= 0
        @webpacker += 1
        assert_equal 1, @webpacker, "webpacker:install expected to be called once, but was called #{@webpacker} times."
      when "webpacker:install:react"
        @react ||= 0
        @react += 1
        assert_equal 1, @react, "webpacker:install:react expected to be called once, but was called #{@react} times."
      end
    end

    generator([destination_root], webpack: "react").stub(:rails_command, command_check) do
      generator.stub :bundle_command, nil do
        quietly { generator.invoke_all }
      end
    end
  end

  def test_generator_if_skip_turbolinks_is_given
    run_generator [destination_root, "--skip-turbolinks"]

    assert_file "Gemfile" do |content|
      assert_no_match(/turbolinks/, content)
    end
    assert_file "app/views/layouts/application.html.erb" do |content|
      assert_no_match(/data-turbolinks-track/, content)
    end
    assert_file "app/assets/javascripts/application.js" do |content|
      assert_no_match(/turbolinks/, content)
    end
  end

  def test_bootsnap
    run_generator

    unless defined?(JRUBY_VERSION)
      assert_gem "bootsnap"
      assert_file "config/boot.rb" do |content|
        assert_match(/require 'bootsnap\/setup'/, content)
      end
    else
       assert_file "Gemfile" do |content|
        assert_no_match(/bootsnap/, content)
      end
      assert_file "config/boot.rb" do |content|
        assert_no_match(/require 'bootsnap\/setup'/, content)
      end
    end
  end

  def test_skip_bootsnap
    run_generator [destination_root, "--skip-bootsnap"]

    assert_file "Gemfile" do |content|
      assert_no_match(/bootsnap/, content)
    end
    assert_file "config/boot.rb" do |content|
      assert_no_match(/require 'bootsnap\/setup'/, content)
    end
  end

  def test_bootsnap_with_dev_option
    run_generator [destination_root, "--dev"]

    assert_file "Gemfile" do |content|
      assert_no_match(/bootsnap/, content)
    end
    assert_file "config/boot.rb" do |content|
      assert_no_match(/require 'bootsnap\/setup'/, content)
    end
  end

  def test_inclusion_of_ruby_version
    run_generator

    assert_file "Gemfile" do |content|
      assert_match(/ruby '#{RUBY_VERSION}'/, content)
    end
    assert_file ".ruby-version" do |content|
      if defined?(JRUBY_VERSION)
        assert_match(/jruby-#{JRUBY_VERSION}/, content)
      else
        assert_match(/ruby-#{RUBY_VERSION}/, content)
      end
    end
  end

  def test_version_control_initializes_git_repo
    run_generator [destination_root]
    assert_directory ".git"
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
      test/fixtures
      test/fixtures/files
      test/controllers
      test/mailers
      test/models
      test/helpers
      test/integration
      tmp
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

  def test_after_bundle_callback
    path = "http://example.org/rails_template"
    template = %{ after_bundle { run 'echo ran after_bundle' } }.dup
    template.instance_eval "def read; self; end" # Make the string respond to read

    check_open = -> *args do
      assert_equal [ path, "Accept" => "application/x-thor-template" ], args
      template
    end

    sequence = ["git init", "install", "exec spring binstub --all", "echo ran after_bundle"]
    @sequence_step ||= 0
    ensure_bundler_first = -> command, options = nil do
      assert_equal sequence[@sequence_step], command, "commands should be called in sequence #{sequence}"
      @sequence_step += 1
    end

    generator([destination_root], template: path).stub(:open, check_open, template) do
      generator.stub(:bundle_command, ensure_bundler_first) do
        generator.stub(:run, ensure_bundler_first) do
          generator.stub(:rails_command, ensure_bundler_first) do
            quietly { generator.invoke_all }
          end
        end
      end
    end

    assert_equal 4, @sequence_step
  end

  def test_gitignore
    run_generator

    assert_file ".gitignore" do |content|
      assert_match(/config\/master\.key/, content)
    end
  end

  def test_system_tests_directory_generated
    run_generator

    assert_file("test/system/.keep")
    assert_directory("test/system")
  end

  unless Gem.win_platform?
    def test_master_key_is_only_readable_by_the_owner
      run_generator

      stat = File.stat("config/master.key")
      assert_equal "100600", sprintf("%o", stat.mode)
    end
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

    def assert_gem(gem, constraint = nil)
      if constraint
        assert_file "Gemfile", /^\s*gem\s+["']#{gem}["'], #{constraint}$*/
      else
        assert_file "Gemfile", /^\s*gem\s+["']#{gem}["']$*/
      end
    end

    def assert_listen_related_configuration
      assert_gem "listen"
      assert_gem "spring-watcher-listen"

      assert_file "config/environments/development.rb" do |content|
        assert_match(/^\s*config\.file_watcher = ActiveSupport::EventedFileUpdateChecker/, content)
      end
    end

    def assert_no_listen_related_configuration
      assert_file "Gemfile" do |content|
        assert_no_match(/listen/, content)
      end

      assert_file "config/environments/development.rb" do |content|
        assert_match(/^\s*# config\.file_watcher = ActiveSupport::EventedFileUpdateChecker/, content)
      end
    end

    def assert_generates_with_bundler(options = {})
      generator([destination_root], options)

      command_check = -> command do
        @install_called ||= 0

        case command
        when "install"
          @install_called += 1
          assert_equal 1, @install_called, "install expected to be called once, but was called #{@install_called} times"
        when "exec spring binstub --all"
          # Called when running tests with spring, let through unscathed.
        end
      end

      generator.stub :bundle_command, command_check do
        quietly { generator.invoke_all }
      end
    end
end
