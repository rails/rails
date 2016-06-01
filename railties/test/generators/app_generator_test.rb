require 'generators/generators_test_helper'
require 'rails/generators/rails/app/app_generator'
require 'generators/shared_generator_tests'

DEFAULT_APP_FILES = %w(
  .gitignore
  README.md
  Gemfile
  Rakefile
  config.ru
  app/assets/javascripts
  app/assets/stylesheets
  app/assets/images
  app/controllers
  app/controllers/concerns
  app/helpers
  app/mailers
  app/models
  app/models/concerns
  app/jobs
  app/views/layouts
  bin/bundle
  bin/rails
  bin/rake
  bin/setup
  config/environments
  config/initializers
  config/locales
  config/cable.yml
  config/puma.rb
  config/spring.rb
  db
  lib
  lib/tasks
  lib/assets
  log
  test/test_helper.rb
  test/fixtures
  test/fixtures/files
  test/controllers
  test/models
  test/helpers
  test/mailers
  test/integration
  vendor
  vendor/assets
  vendor/assets/stylesheets
  vendor/assets/javascripts
  tmp
  tmp/cache
  tmp/cache/assets
)

class AppGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments [destination_root]

  # brings setup, teardown, and some tests
  include SharedGeneratorTests

  def default_files
    ::DEFAULT_APP_FILES
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
    content = capture(:stderr){ run_generator [File.join(destination_root, "43-things")] }
    assert_equal "Invalid application name 43-things. Please give a name which does not start with numbers.\n", content
  end

  def test_invalid_application_name_is_fixed
    run_generator [File.join(destination_root, "things-43")]
    assert_file "things-43/config/environment.rb", /Rails\.application\.initialize!/
    assert_file "things-43/config/application.rb", /^module Things43$/
  end

  def test_application_new_exits_with_non_zero_code_on_invalid_application_name
    quietly { system 'rails new test --no-rc' }
    assert_equal false, $?.success?
  end

  def test_application_new_exits_with_message_and_non_zero_code_when_generating_inside_existing_rails_directory
    app_root = File.join(destination_root, 'myfirstapp')
    run_generator [app_root]
    output = nil
    Dir.chdir(app_root) do
      output = `rails new mysecondapp`
    end
    assert_equal "Can't initialize a new Rails application within the directory of another, please change to a non-Rails directory first.\nType 'rails' for help.\n", output
    assert_equal false, $?.success?
  end

  def test_application_new_show_help_message_inside_existing_rails_directory
    app_root = File.join(destination_root, 'myfirstapp')
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
        assert_file "myapp_moved/config/initializers/session_store.rb", /_myapp_session/
      end
    end
  end

  def test_rails_update_generates_correct_session_key
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.send(:update_config_files) }
      assert_file "myapp/config/initializers/session_store.rb", /_myapp_session/
    end
  end

  def test_new_application_use_json_serialzier
    run_generator

    assert_file("config/initializers/cookies_serializer.rb", /Rails\.application\.config\.action_dispatch\.cookies_serializer = :json/)
  end

  def test_new_application_not_include_api_initializers
    run_generator

    assert_no_file 'config/initializers/cors.rb'
  end

  def test_rails_update_keep_the_cookie_serializer_if_it_is_already_configured
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.send(:update_config_files) }
      assert_file("#{app_root}/config/initializers/cookies_serializer.rb", /Rails\.application\.config\.action_dispatch\.cookies_serializer = :json/)
    end
  end

  def test_rails_update_set_the_cookie_serializer_to_marshal_if_it_is_not_already_configured
    app_root = File.join(destination_root, 'myapp')
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

  def test_rails_update_dont_set_file_watcher
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.send(:update_config_files) }
      assert_file "#{app_root}/config/environments/development.rb" do |content|
        assert_match(/# config.file_watcher/, content)
      end
    end
  end

  def test_rails_update_does_not_create_new_framework_defaults_by_default
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    FileUtils.rm("#{app_root}/config/initializers/new_framework_defaults.rb")

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.send(:update_config_files) }
      assert_no_file "#{app_root}/config/initializers/new_framework_defaults.rb"
    end
  end

  def test_rails_update_does_not_new_framework_defaults_if_already_present
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    FileUtils.touch("#{app_root}/config/initializers/new_framework_defaults.rb")

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.send(:update_config_files) }
      assert_file "#{app_root}/config/initializers/new_framework_defaults.rb"
    end
  end

  def test_rails_update_does_not_create_rack_cors
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.send(:update_config_files) }
      assert_no_file "#{app_root}/config/initializers/cors.rb"
    end
  end

  def test_rails_update_does_not_remove_rack_cors_if_already_present
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    FileUtils.touch("#{app_root}/config/initializers/cors.rb")

    stub_rails_application(app_root) do
      generator = Rails::Generators::AppGenerator.new ["rails"], [], destination_root: app_root, shell: @shell
      generator.send(:app_const)
      quietly { generator.send(:update_config_files) }
      assert_file "#{app_root}/config/initializers/cors.rb"
    end
  end

  def test_application_names_are_not_singularized
    run_generator [File.join(destination_root, "hats")]
    assert_file "hats/config/environment.rb", /Rails\.application\.initialize!/
  end

  def test_gemfile_has_no_whitespace_errors
    run_generator
    absolute = File.expand_path("Gemfile", destination_root)
    File.open(absolute, 'r') do |f|
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

  def test_config_another_database
    run_generator([destination_root, "-d", "mysql"])
    assert_file "config/database.yml", /mysql/
    if defined?(JRUBY_VERSION)
      assert_gem "activerecord-jdbcmysql-adapter"
    else
      assert_gem "mysql2", "'>= 0.3.18', '< 0.5'"
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
      assert_gem "pg", "'~> 0.18'"
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

  def test_generator_without_skips
    run_generator
    assert_file "config/application.rb", /\s+require\s+["']rails\/all["']/
    assert_file "config/environments/development.rb" do |content|
      assert_match(/config\.action_mailer\.raise_delivery_errors = false/, content)
    end
    assert_file "config/environments/test.rb" do |content|
      assert_match(/config\.action_mailer\.delivery_method = :test/, content)
    end
    assert_file "config/environments/production.rb" do |content|
      assert_match(/# config\.action_mailer\.raise_delivery_errors = false/, content)
    end
  end

  def test_generator_defaults_to_puma_version
    run_generator [destination_root]
    assert_gem "puma", "'~> 3.0'"
  end

  def test_generator_if_skip_puma_is_given
    run_generator [destination_root, "--skip-puma"]
    assert_no_file "config/puma.rb"
    assert_file "Gemfile" do |content|
      assert_no_match(/puma/, content)
    end
  end

  def test_generator_if_skip_active_record_is_given
    run_generator [destination_root, "--skip-active-record"]
    assert_no_file "config/database.yml"
    assert_no_file "app/models/application_record.rb"
    assert_file "config/application.rb", /#\s+require\s+["']active_record\/railtie["']/
    assert_file "test/test_helper.rb" do |helper_content|
      assert_no_match(/fixtures :all/, helper_content)
    end

    assert_file "config/initializers/new_framework_defaults.rb" do |initializer_content|
      assert_no_match(/belongs_to_required_by_default/, initializer_content)
    end
  end

  def test_generator_if_skip_action_mailer_is_given
    run_generator [destination_root, "--skip-action-mailer"]
    assert_file "config/application.rb", /#\s+require\s+["']action_mailer\/railtie["']/
    assert_file "config/environments/development.rb" do |content|
      assert_no_match(/config\.action_mailer/, content)
    end
    assert_file "config/environments/test.rb" do |content|
      assert_no_match(/config\.action_mailer/, content)
    end
    assert_file "config/environments/production.rb" do |content|
      assert_no_match(/config\.action_mailer/, content)
    end
  end

  def test_generator_has_assets_gems
    run_generator

    assert_gem 'sass-rails'
    assert_gem 'uglifier'
  end

  def test_generator_if_skip_sprockets_is_given
    run_generator [destination_root, "--skip-sprockets"]
    assert_no_file "config/initializers/assets.rb"
    assert_file "config/application.rb" do |content|
      assert_match(/#\s+require\s+["']sprockets\/railtie["']/, content)
    end
    assert_file "Gemfile" do |content|
      assert_no_match(/jquery-rails/, content)
      assert_no_match(/sass-rails/, content)
      assert_no_match(/uglifier/, content)
      assert_no_match(/coffee-rails/, content)
    end
    assert_file "config/environments/development.rb" do |content|
      assert_no_match(/config\.assets\.debug = true/, content)
    end
    assert_file "config/environments/production.rb" do |content|
      assert_no_match(/config\.assets\.digest = true/, content)
      assert_no_match(/config\.assets\.js_compressor = :uglifier/, content)
      assert_no_match(/config\.assets\.css_compressor = :sass/, content)
    end
  end

  def test_generator_if_skip_action_cable_is_given
    run_generator [destination_root, "--skip-action-cable"]
    assert_file "config/application.rb", /#\s+require\s+["']action_cable\/engine["']/
    assert_no_file "config/cable.yml"
    assert_no_file "app/assets/javascripts/cable.js"
    assert_no_file "app/channels"
    assert_file "Gemfile" do |content|
      assert_no_match(/redis/, content)
    end
  end

  def test_action_cable_redis_gems
    run_generator
    assert_file "Gemfile", /^# gem 'redis'/
  end

  def test_inclusion_of_javascript_runtime
    run_generator
    if defined?(JRUBY_VERSION)
      assert_gem "therubyrhino"
    else
      assert_file "Gemfile", /# gem 'therubyracer', platforms: :ruby/
    end
  end

  def test_jquery_is_the_default_javascript_library
    run_generator
    assert_file "app/assets/javascripts/application.js" do |contents|
      assert_match %r{^//= require jquery}, contents
      assert_match %r{^//= require jquery_ujs}, contents
    end
    assert_gem "jquery-rails"
  end

  def test_other_javascript_libraries
    run_generator [destination_root, '-j', 'prototype']
    assert_file "app/assets/javascripts/application.js" do |contents|
      assert_match %r{^//= require prototype}, contents
      assert_match %r{^//= require prototype_ujs}, contents
    end
    assert_gem "prototype-rails"
  end

  def test_javascript_is_skipped_if_required
    run_generator [destination_root, "--skip-javascript"]

    assert_no_file "app/assets/javascripts"
    assert_no_file "vendor/assets/javascripts"

    assert_file "app/views/layouts/application.html.erb" do |contents|
      assert_match(/stylesheet_link_tag\s+'application', media: 'all' %>/, contents)
      assert_no_match(/javascript_include_tag\s+'application' \%>/, contents)
    end

    assert_file "Gemfile" do |content|
      assert_no_match(/coffee-rails/, content)
      assert_no_match(/jquery-rails/, content)
    end
  end

  def test_inclusion_of_jbuilder
    run_generator
    assert_gem 'jbuilder'
  end

  def test_inclusion_of_a_debugger
    run_generator
    if defined?(JRUBY_VERSION) || RUBY_ENGINE == "rbx"
      assert_file "Gemfile" do |content|
        assert_no_match(/byebug/, content)
      end
    else
      assert_gem 'byebug'
    end
  end

  def test_inclusion_of_listen_related_configuration_by_default
    run_generator
    if RbConfig::CONFIG['host_os'] =~ /darwin|linux/
      assert_listen_related_configuration
    else
      assert_no_listen_related_configuration
    end
  end

  def test_non_inclusion_of_listen_related_configuration_if_skip_listen
    run_generator [destination_root, '--skip-listen']
    assert_no_listen_related_configuration
  end

  def test_evented_file_update_checker_config
    run_generator
    assert_file 'config/environments/development.rb' do |content|
      if RbConfig::CONFIG['host_os'] =~ /darwin|linux/
        assert_match(/^\s*config.file_watcher = ActiveSupport::EventedFileUpdateChecker/, content)
      else
        assert_match(/^\s*# config.file_watcher = ActiveSupport::EventedFileUpdateChecker/, content)
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
    action :file, 'lib/test_file.rb', 'heres test data'
    assert_file 'lib/test_file.rb', 'heres test data'
  end

  def test_tests_are_removed_from_frameworks_if_skip_test_is_given
    run_generator [destination_root, "--skip-test"]
    assert_file "config/application.rb", /#\s+require\s+["']rails\/test_unit\/railtie["']/
  end

  def test_no_active_record_or_tests_if_skips_given
    run_generator [destination_root, "--skip-test", "--skip-active-record"]
    assert_file "config/application.rb", /#\s+require\s+["']rails\/test_unit\/railtie["']/
    assert_file "config/application.rb", /#\s+require\s+["']active_record\/railtie["']/
    assert_file "config/application.rb", /\s+require\s+["']active_job\/railtie["']/
  end

  def test_new_hash_style
    run_generator
    assert_file "config/initializers/session_store.rb" do |file|
      assert_match(/config.session_store :cookie_store, key: '_.+_session'/, file)
    end
  end

  def test_pretend_option
    output = run_generator [File.join(destination_root, "myapp"), "--pretend"]
    assert_no_match(/run  bundle install/, output)
  end

  def test_application_name_with_spaces
    path = File.join(destination_root, "foo bar")

    # This also applies to MySQL apps but not with SQLite
    run_generator [path, "-d", 'postgresql']

    assert_file "foo bar/config/database.yml", /database: foo_bar_development/
    assert_file "foo bar/config/initializers/session_store.rb", /key: '_foo_bar/
  end

  def test_web_console
    run_generator
    assert_gem 'web-console'
  end

  def test_web_console_with_dev_option
    run_generator [destination_root, "--dev"]

    assert_file "Gemfile" do |content|
      assert_match(/gem 'web-console',\s+github: 'rails\/web-console'/, content)
      assert_no_match(/\Agem 'web-console'\z/, content)
    end
  end

  def test_web_console_with_edge_option
    run_generator [destination_root, "--edge"]

    assert_file "Gemfile" do |content|
      assert_match(/gem 'web-console',\s+github: 'rails\/web-console'/, content)
      assert_no_match(/\Agem 'web-console'\z/, content)
    end
  end

  def test_spring
    run_generator
    assert_gem 'spring'
  end

  def test_spring_binstubs
    jruby_skip "spring doesn't run on JRuby"
    command_check = -> command do
      @binstub_called ||= 0

      case command
      when 'install'
        # Called when running bundle, we just want to stub it so nothing to do here.
      when 'exec spring binstub --all'
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

    assert_no_file 'config/spring.rb'
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

  def test_gitignore_when_sqlite3
    run_generator

    assert_file '.gitignore' do |content|
      assert_match(/sqlite3/, content)
    end
  end

  def test_gitignore_when_no_active_record
    run_generator [destination_root, '--skip-active-record']

    assert_file '.gitignore' do |content|
      assert_no_match(/sqlite/i, content)
    end
  end

  def test_gitignore_when_non_sqlite3_db
    run_generator([destination_root, "-d", "mysql"])

    assert_file '.gitignore' do |content|
      assert_no_match(/sqlite/i, content)
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
      test/fixtures
      test/fixtures/files
      test/controllers
      test/mailers
      test/models
      test/helpers
      test/integration
      tmp
      vendor/assets/stylesheets
    )
    folders_with_keep.each do |folder|
      assert_file("#{folder}/.keep")
    end
  end

  def test_psych_gem
    run_generator
    gem_regex = /gem 'psych',\s+'~> 2.0',\s+platforms: :rbx/

    assert_file "Gemfile" do |content|
      if defined?(Rubinius)
        assert_match(gem_regex, content)
      else
        assert_no_match(gem_regex, content)
      end
    end
  end

  def test_after_bundle_callback
    path = 'http://example.org/rails_template'
    template = %{ after_bundle { run 'echo ran after_bundle' } }
    template.instance_eval "def read; self; end" # Make the string respond to read

    check_open = -> *args do
      assert_equal [ path, 'Accept' => 'application/x-thor-template' ], args
      template
    end

    sequence = ['install', 'exec spring binstub --all', 'echo ran after_bundle']
      @sequence_step ||= 0
    ensure_bundler_first = -> command do
      assert_equal sequence[@sequence_step], command, "commands should be called in sequence #{sequence}"
      @sequence_step += 1
    end

    generator([destination_root], template: path).stub(:open, check_open, template) do
      generator.stub(:bundle_command, ensure_bundler_first) do
        generator.stub(:run, ensure_bundler_first) do
          quietly { generator.invoke_all }
        end
      end
    end

    assert_equal 3, @sequence_step
  end

  protected

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
    assert_gem 'listen'
    assert_gem 'spring-watcher-listen'

    assert_file 'config/environments/development.rb' do |content|
      assert_match(/^\s*config.file_watcher = ActiveSupport::EventedFileUpdateChecker/, content)
    end
  end

  def assert_no_listen_related_configuration
    assert_file 'Gemfile' do |content|
      assert_no_match(/listen/, content)
    end

    assert_file 'config/environments/development.rb' do |content|
      assert_match(/^\s*# config.file_watcher = ActiveSupport::EventedFileUpdateChecker/, content)
    end
  end
end
