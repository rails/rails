require 'generators/generators_test_helper'
require 'rails/generators/rails/app/app_generator'
require 'generators/shared_generator_tests'
require 'mocha/setup' # FIXME: stop using mocha

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
  app/views/layouts
  bin/bundle
  bin/rails
  bin/rake
  bin/setup
  config/environments
  config/initializers
  config/locales
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

    assert_file("app/views/layouts/application.html.erb", /stylesheet_link_tag\s+'application', media: 'all', 'data-turbolinks-track' => true/)
    assert_file("app/views/layouts/application.html.erb", /javascript_include_tag\s+'application', 'data-turbolinks-track' => true/)
    assert_file("app/assets/stylesheets/application.css")
    assert_file("app/assets/javascripts/application.js")
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

    Rails.application.config.root = app_moved_root
    Rails.application.class.stubs(:name).returns("Myapp")
    Rails.application.stubs(:is_a?).returns(Rails::Application)

    FileUtils.mv(app_root, app_moved_root)

    # make sure we are in correct dir
    FileUtils.cd(app_moved_root)

    generator = Rails::Generators::AppGenerator.new ["rails"], { with_dispatchers: true },
                                                               destination_root: app_moved_root, shell: @shell
    generator.send(:app_const)
    quietly { generator.send(:update_config_files) }
    assert_file "myapp_moved/config/environment.rb", /Rails\.application\.initialize!/
    assert_file "myapp_moved/config/initializers/session_store.rb", /_myapp_session/
  end

  def test_rails_update_generates_correct_session_key
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    Rails.application.config.root = app_root
    Rails.application.class.stubs(:name).returns("Myapp")
    Rails.application.stubs(:is_a?).returns(Rails::Application)

    generator = Rails::Generators::AppGenerator.new ["rails"], { with_dispatchers: true }, destination_root: app_root, shell: @shell
    generator.send(:app_const)
    quietly { generator.send(:update_config_files) }
    assert_file "myapp/config/initializers/session_store.rb", /_myapp_session/
  end

  def test_new_application_use_json_serialzier
    run_generator

    assert_file("config/initializers/cookies_serializer.rb", /Rails\.application\.config\.action_dispatch\.cookies_serializer = :json/)
  end

  def test_rails_update_keep_the_cookie_serializer_if_it_is_already_configured
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    Rails.application.config.root = app_root
    Rails.application.class.stubs(:name).returns("Myapp")
    Rails.application.stubs(:is_a?).returns(Rails::Application)

    generator = Rails::Generators::AppGenerator.new ["rails"], { with_dispatchers: true }, destination_root: app_root, shell: @shell
    generator.send(:app_const)
    quietly { generator.send(:update_config_files) }
    assert_file("#{app_root}/config/initializers/cookies_serializer.rb", /Rails\.application\.config\.action_dispatch\.cookies_serializer = :json/)
  end

  def test_rails_update_does_not_create_callback_terminator_initializer
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    FileUtils.rm("#{app_root}/config/initializers/callback_terminator.rb")

    Rails.application.config.root = app_root
    Rails.application.class.stubs(:name).returns("Myapp")
    Rails.application.stubs(:is_a?).returns(Rails::Application)

    generator = Rails::Generators::AppGenerator.new ["rails"], { with_dispatchers: true }, destination_root: app_root, shell: @shell
    generator.send(:app_const)
    quietly { generator.send(:update_config_files) }
    assert_no_file "#{app_root}/config/initializers/callback_terminator.rb"
  end

  def test_rails_update_does_not_remove_callback_terminator_initializer_if_already_present
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    FileUtils.touch("#{app_root}/config/initializers/callback_terminator.rb")

    Rails.application.config.root = app_root
    Rails.application.class.stubs(:name).returns("Myapp")
    Rails.application.stubs(:is_a?).returns(Rails::Application)

    generator = Rails::Generators::AppGenerator.new ["rails"], { with_dispatchers: true }, destination_root: app_root, shell: @shell
    generator.send(:app_const)
    quietly { generator.send(:update_config_files) }
    assert_file "#{app_root}/config/initializers/callback_terminator.rb"
  end

  def test_rails_update_set_the_cookie_serializer_to_marchal_if_it_is_not_already_configured
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    FileUtils.rm("#{app_root}/config/initializers/cookies_serializer.rb")

    Rails.application.config.root = app_root
    Rails.application.class.stubs(:name).returns("Myapp")
    Rails.application.stubs(:is_a?).returns(Rails::Application)

    generator = Rails::Generators::AppGenerator.new ["rails"], { with_dispatchers: true }, destination_root: app_root, shell: @shell
    generator.send(:app_const)
    quietly { generator.send(:update_config_files) }
    assert_file("#{app_root}/config/initializers/cookies_serializer.rb", /Rails\.application\.config\.action_dispatch\.cookies_serializer = :marshal/)
  end

  def test_rails_update_does_not_create_active_record_belongs_to_required_by_default
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    FileUtils.rm("#{app_root}/config/initializers/active_record_belongs_to_required_by_default.rb")

    Rails.application.config.root = app_root
    Rails.application.class.stubs(:name).returns("Myapp")
    Rails.application.stubs(:is_a?).returns(Rails::Application)

    generator = Rails::Generators::AppGenerator.new ["rails"], { with_dispatchers: true }, destination_root: app_root, shell: @shell
    generator.send(:app_const)
    quietly { generator.send(:update_config_files) }
    assert_no_file "#{app_root}/config/initializers/active_record_belongs_to_required_by_default.rb"
  end

  def test_rails_update_does_not_remove_active_record_belongs_to_required_by_default_if_already_present
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    FileUtils.touch("#{app_root}/config/initializers/active_record_belongs_to_required_by_default.rb")

    Rails.application.config.root = app_root
    Rails.application.class.stubs(:name).returns("Myapp")
    Rails.application.stubs(:is_a?).returns(Rails::Application)

    generator = Rails::Generators::AppGenerator.new ["rails"], { with_dispatchers: true }, destination_root: app_root, shell: @shell
    generator.send(:app_const)
    quietly { generator.send(:update_config_files) }
    assert_file "#{app_root}/config/initializers/active_record_belongs_to_required_by_default.rb"
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
      assert_gem "mysql2"
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
      assert_gem "pg"
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

  def test_generator_if_skip_active_record_is_given
    run_generator [destination_root, "--skip-active-record"]
    assert_no_file "config/database.yml"
    assert_no_file "config/initializers/active_record_belongs_to_required_by_default.rb"
    assert_file "config/application.rb", /#\s+require\s+["']active_record\/railtie["']/
    assert_file "test/test_helper.rb" do |helper_content|
      assert_no_match(/fixtures :all/, helper_content)
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

  def test_generator_if_skip_sprockets_is_given
    run_generator [destination_root, "--skip-sprockets"]
    assert_no_file "config/initializers/assets.rb"
    assert_file "config/application.rb" do |content|
      assert_match(/#\s+require\s+["']sprockets\/railtie["']/, content)
    end
    assert_file "Gemfile" do |content|
      assert_no_match(/sass-rails/, content)
      assert_no_match(/uglifier/, content)
      assert_match(/coffee-rails/, content)
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

  def test_template_from_dir_pwd
    FileUtils.cd(Rails.root)
    assert_match(/It works from file!/, run_generator([destination_root, "-m", "lib/template.rb"]))
  end

  def test_usage_read_from_file
    File.expects(:read).returns("USAGE FROM FILE")
    assert_equal "USAGE FROM FILE", Rails::Generators::AppGenerator.desc
  end

  def test_default_usage
    Rails::Generators::AppGenerator.expects(:usage_path).returns(nil)
    assert_match(/Create rails files for app generator/, Rails::Generators::AppGenerator.desc)
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
    path = File.join(destination_root, "foo bar".shellescape)

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
      assert_match(/gem 'web-console',\s+github: "rails\/web-console"/, content)
      assert_no_match(/gem 'web-console', '~> 2.0'/, content)
    end
  end

  def test_web_console_with_edge_option
    run_generator [destination_root, "--edge"]

    assert_file "Gemfile" do |content|
      assert_match(/gem 'web-console',\s+github: "rails\/web-console"/, content)
      assert_no_match(/gem 'web-console', '~> 2.0'/, content)
    end
  end

  def test_spring
    run_generator
    assert_gem 'spring'
  end

  def test_spring_binstubs
    jruby_skip "spring doesn't run on JRuby"
    generator.stubs(:bundle_command).with('install')
    generator.expects(:bundle_command).with('exec spring binstub --all').once
    quietly { generator.invoke_all }
  end

  def test_spring_no_fork
    jruby_skip "spring doesn't run on JRuby"
    Process.stubs(:respond_to?).with(:fork).returns(false)
    run_generator

    assert_file "Gemfile" do |content|
      assert_no_match(/spring/, content)
    end
  end

  def test_skip_spring
    run_generator [destination_root, "--skip-spring"]

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

    generator([destination_root], template: path).expects(:open).with(path, 'Accept' => 'application/x-thor-template').returns(template)

    bundler_first = sequence('bundle, binstubs, after_bundle')
    generator.expects(:bundle_command).with('install').once.in_sequence(bundler_first)
    generator.expects(:bundle_command).with('exec spring binstub --all').in_sequence(bundler_first)
    generator.expects(:run).with('echo ran after_bundle').in_sequence(bundler_first)

    quietly { generator.invoke_all }
  end

  protected

  def action(*args, &block)
    capture(:stdout) { generator.send(*args, &block) }
  end

  def assert_gem(gem)
    assert_file "Gemfile", /^\s*gem\s+["']#{gem}["']$*/
  end
end
