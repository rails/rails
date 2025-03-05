# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/app/app_generator"
require "generators/shared_generator_tests"

DEFAULT_APP_FILES = %w(
  .dockerignore
  .git
  .gitattributes
  .github/dependabot.yml
  .github/workflows/ci.yml
  .gitignore
  .rubocop.yml
  .ruby-version
  Dockerfile
  Gemfile
  README.md
  Rakefile
  app/assets/images/.keep
  app/assets/stylesheets/application.css
  app/controllers/application_controller.rb
  app/controllers/concerns/.keep
  app/helpers/application_helper.rb
  app/jobs/application_job.rb
  app/mailers/application_mailer.rb
  app/models/application_record.rb
  app/models/concerns/.keep
  app/views/layouts/application.html.erb
  app/views/layouts/mailer.html.erb
  app/views/layouts/mailer.text.erb
  app/views/pwa/manifest.json.erb
  app/views/pwa/service-worker.js
  bin/brakeman
  bin/dev
  bin/docker-entrypoint
  bin/rails
  bin/rake
  bin/rubocop
  bin/setup
  bin/thrust
  config.ru
  config/application.rb
  config/boot.rb
  config/cable.yml
  config/credentials.yml.enc
  config/database.yml
  config/environment.rb
  config/environments/development.rb
  config/environments/production.rb
  config/environments/test.rb
  config/initializers/assets.rb
  config/initializers/content_security_policy.rb
  config/initializers/filter_parameter_logging.rb
  config/initializers/inflections.rb
  config/locales/en.yml
  config/master.key
  config/puma.rb
  config/routes.rb
  config/storage.yml
  db/seeds.rb
  lib/tasks/.keep
  log/.keep
  public/400.html
  public/404.html
  public/406-unsupported-browser.html
  public/422.html
  public/500.html
  public/icon.png
  public/icon.svg
  public/robots.txt
  script/.keep
  storage/.keep
  test/application_system_test_case.rb
  test/controllers/.keep
  test/fixtures/files/.keep
  test/helpers/.keep
  test/integration/.keep
  test/mailers/.keep
  test/models/.keep
  test/system/.keep
  test/test_helper.rb
  tmp/.keep
  tmp/pids/.keep
  tmp/storage/.keep
  vendor/.keep
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

  def test_invalid_javascript_option_raises_an_error
    content = capture(:stderr) { run_generator([destination_root, "-j", "unknown"]) }
    assert_match(/Expected '--javascript' to be one of/, content)
  end

  def test_invalid_css_option_raises_an_error
    content = capture(:stderr) { run_generator([destination_root, "-c", "unknown"]) }
    assert_match(/Expected '--css' to be one of/, content)
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

  def test_app_update
    run_generator

    defaults_path = "config/initializers/new_framework_defaults_#{Rails::VERSION::MAJOR}_#{Rails::VERSION::MINOR}.rb"

    assert_no_file defaults_path
    assert_no_file "config/initializers/cors.rb"

    run_app_update

    assert_file defaults_path
    assert_no_file "config/initializers/cors.rb"
  end

  def test_app_update_supports_skip
    run_generator
    FileUtils.cd(destination_root) do
      config = "config/application.rb"
      File.open(config, "a") do |file|
        file.puts "# some configuration"
      end
      assert_no_changes -> { File.readlines(config) } do
        run_app_update(flags: "--skip")
      end
    end
  end

  def test_app_update_supports_pretend
    run_generator
    FileUtils.cd(destination_root) do
      config = "config/application.rb"
      File.open(config, "a") do |file|
        file.puts "# some configuration"
      end
      assert_no_changes -> { File.readlines(config) } do
        run_app_update(flags: "--pretend --force")
      end
      defaults_path = "config/initializers/new_framework_defaults_#{Rails::VERSION::MAJOR}_#{Rails::VERSION::MINOR}.rb"
      assert_no_file defaults_path
    end
  end

  def test_app_update_does_not_remove_rack_cors_if_already_present
    run_generator
    FileUtils.touch("#{destination_root}/config/initializers/cors.rb")
    run_app_update

    assert_file "config/initializers/cors.rb"
  end

  def test_app_update_generates_public_folders
    run_generator

    FileUtils.rm_rf("#{destination_root}/public/406-unsupported-browser.html")

    run_app_update

    assert_file "public/406-unsupported-browser.html"
  end

  def test_app_update_does_not_generate_assets_initializer_when_asset_pipeline_is_not_used
    run_generator [destination_root, "--skip-asset-pipeline"]
    run_app_update

    assert_no_file "config/initializers/assets.rb"
  end

  def test_app_update_does_not_generate_action_cable_contents_when_skip_action_cable_is_given
    run_generator [destination_root, "--skip-action-cable"]
    run_app_update

    assert_no_file "config/cable.yml"
    assert_file "config/environments/production.rb" do |content|
      assert_no_match(/config\.action_cable/, content)
    end
    assert_file "config/database.yml" do |content|
      assert_no_match(/cable:/, content)
    end
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

  def test_app_update_preserves_skip_brakeman
    run_generator [ destination_root, "--skip-brakeman" ]

    FileUtils.cd(destination_root) do
      assert_no_changes -> { File.exist?("bin/brakeman") } do
        run_app_update
      end
    end
  end

  def test_app_update_preserves_skip_rubocop
    run_generator [ destination_root, "--skip-rubocop" ]

    FileUtils.cd(destination_root) do
      assert_no_changes -> { File.exist?("bin/rubocop") } do
        run_app_update
      end
    end
  end

  def test_app_update_preserves_skip_thruster
    run_generator [ destination_root, "--skip-thruster" ]

    FileUtils.cd(destination_root) do
      assert_no_changes -> { File.exist?("bin/thrust") } do
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

  def test_app_update_silence_deprecate_message
    run_generator

    FileUtils.cd(destination_root) do
      File.open("config/initializers/deprecation.rb", "a") do |file|
        file.puts "Rails.deprecator.warn('test deprecation message')"
      end

      stderr = capture(:stderr) { run_app_update }
      assert_no_match(/test deprecation message/, stderr)
    end
  end

  def test_generator_skips_action_mailbox_when_skip_action_mailbox_is_given
    run_generator [destination_root, "--skip-action-mailbox"]
    assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']action_mailbox\/engine["']/
  end

  def test_generator_skips_action_text_when_skip_action_text_is_given
    run_generator [destination_root, "--skip-action-text"]
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
    assert_file "MyWebSite/app/views/layouts/application.html.erb", /content_for\(:title\) \|\| "My Web Site"/
    assert_file "MyWebSite/app/views/layouts/application.html.erb", /meta\sname="application-name"\scontent="My Web Site/
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
    assert_gem "sqlite3", '">= 2.1"'
  end

  def test_config_mysql_database
    run_generator([destination_root, "-d", "mysql"])
    assert_file "config/database.yml", /mysql/
    assert_gem "mysql2", '"~> 0.5"'
  end

  def test_config_database_app_name_with_period
    run_generator [File.join(destination_root, "common.usage.com"), "-d", "postgresql"]
    assert_file "common.usage.com/config/database.yml", /common_usage_com/
  end

  def test_config_postgresql_database
    run_generator([destination_root, "-d", "postgresql"])
    assert_file "config/database.yml", /postgresql/
    assert_gem "pg", '"~> 1.1"'
  end

  def test_generator_defaults_to_puma_version
    run_generator [destination_root]
    assert_gem "puma", /"\W+ \d/
  end

  def test_action_cable_redis_gems
    run_generator [destination_root, "--skip-solid"]
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

    assert_no_directory("test")

    assert_file ".github/workflows/ci.yml" do |file|
      assert_no_match(/test:.\s*runs-on/m, file)
    end
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

    assert_directory("test")

    assert_no_directory("test/system")

    assert_file ".github/workflows/ci.yml" do |content|
      assert_match(/db:test:prepare test/, content)
      assert_no_match(/test:system/, content)
      assert_no_match(/screenshots/, content)
    end
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
      assert_match(/stylesheet_link_tag\s+:app %>/, contents)
    end

    assert_file ".github/workflows/ci.yml" do |file|
      assert_no_match("scan_js", file)
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

  def test_inclusion_of_thruster
    run_generator
    assert_gem "thruster"
  end

  def test_thruster_is_skipped_if_required
    run_generator [destination_root, "--skip-thruster"]

    assert_no_gem "thruster"
    assert_no_file "bin/thrust"
  end

  def test_inclusion_of_rubocop
    run_generator
    assert_gem "rubocop-rails-omakase"
    assert_file "config/environments/development.rb", %r|# Apply autocorrection by RuboCop to files generated by `bin/rails generate`\.|
  end

  def test_quiet_assets_in_development
    run_generator
    assert_file "config/environments/development.rb", /config\.assets\.quiet = true/
  end

  def test_rubocop_is_skipped_if_required
    run_generator [destination_root, "--skip-rubocop"]

    assert_no_gem "rubocop-rails-omakase"
    assert_no_file "bin/rubocop"
    assert_no_file ".rubocop.yml"
    assert_file "config/environments/development.rb" do |content|
      assert_no_match(%r|# Apply autocorrection by RuboCop to files generated by `bin/rails generate`\.|, content)
    end
  end

  def test_inclusion_of_brakeman
    run_generator
    assert_gem "brakeman"
  end

  def test_brakeman_is_skipped_if_required
    run_generator [destination_root, "--skip-brakeman"]

    assert_no_gem "brakeman"
    assert_no_file "bin/brakeman"
  end

  def test_both_brakeman_and_rubocop_binstubs_are_skipped_if_required
    run_generator [destination_root, "--skip-brakeman", "--skip-rubocop"]

    assert_no_file "bin/rubocop"
    assert_no_file "bin/brakeman"
  end

  def test_inclusion_of_ci_files
    run_generator
    assert_file ".github/workflows/ci.yml"
    assert_file ".github/dependabot.yml"
  end

  def test_ci_files_are_skipped_if_required
    run_generator [destination_root, "--skip-ci"]

    assert_no_file ".github/workflows/ci.yml"
    assert_no_file ".github/dependabot.yml"
  end

  def test_configuration_of_solid
    generator [destination_root]
    run_generator_instance

    assert_gem "solid_cache"
    assert_gem "solid_queue"
    assert_gem "solid_cable"

    assert_file "config/database.yml" do |content|
      assert_match(%r{cache:}, content)
      assert_match(%r{queue:}, content)
      assert_match(%r{cable:}, content)
    end
  end

  def test_inclusion_of_kamal_files
    generator [destination_root]
    run_generator_instance

    assert_file "config/deploy.yml"
    assert_file ".kamal/secrets"
  end

  def test_kamal_files_are_skipped_if_required
    generator [destination_root], ["--skip-kamal"]
    run_generator_instance

    assert_empty @bundle_commands.grep("binstubs kamal")
    assert_empty @bundle_commands.grep("exec kamal init")

    assert_no_file "config/deploy.yml"
    assert_no_file ".kamal/secrets"
  end

  def test_database_yml_skip_kamal
    run_generator [destination_root, "--skip-kamal"]

    assert_file("config/database.yml") do |content|
      assert_match("db/queue_migrate", content)
      assert_match("db/cache_migrate", content)
      assert_match("db/cable_migrate", content)
    end
  end

  def test_inclusion_of_kamal_storage_volume
    generator [destination_root]
    run_generator_instance

    assert_equal 1, @bundle_commands.count("binstubs kamal")
    assert_equal 1, @bundle_commands.count("exec kamal init")

    assert_file "config/deploy.yml" do |content|
      assert_match(%r{storage:/rails/storage}, content)
    end
  end

  def test_inclusion_of_kamal_storage_volume_if_only_skip_active_storage_is_given
    generator [destination_root], ["--skip-active-storage"]
    run_generator_instance

    assert_equal 1, @bundle_commands.count("binstubs kamal")
    assert_equal 1, @bundle_commands.count("exec kamal init")

    assert_file "config/deploy.yml" do |content|
      assert_match(%r{storage:/rails/storage}, content)
    end
  end

  def test_kamal_storage_volume_is_skipped_if_required
    generator [destination_root], ["--skip-active-storage", "--database=postgresql"]
    run_generator_instance

    assert_equal 1, @bundle_commands.count("binstubs kamal")
    assert_equal 1, @bundle_commands.count("exec kamal init")

    assert_file "config/deploy.yml" do |content|
      assert_no_match(%r{storage:/rails/storage}, content)
    end
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

    assert_not_empty @bundle_commands.grep(/^install/)
  end

  def test_generation_runs_bundle_lock_for_linux
    generator([destination_root])
    run_generator_instance

    assert_not_empty @bundle_commands.grep(/\Alock --add-platform=\S+-linux/)
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

  def test_skip_active_job_option
    run_generator [destination_root, "--skip-active-job"]

    ["production", "development", "test"].each do |env|
      assert_file "config/environments/#{env}.rb" do |content|
        assert_no_match(/active_job/, content)
      end
    end
  end

  def test_skip_solid_option
    generator([destination_root], skip_solid: true)
    run_generator_instance

    assert_not_includes @rails_commands, "solid_cache:install solid_queue:install solid_cable:install", "`solid_cache:install solid_queue:install solid_cable:install` expected to not be called."
    assert_no_gem "solid_cache"
    assert_no_gem "solid_queue"
    assert_no_gem "solid_cable"
  end

  def test_skip_javascript_option
    generator([destination_root], skip_javascript: true)

    run_generator_instance

    assert_not_includes @rails_commands, "importmap:install", "`importmap:install` expected to not be called."
    assert_not_includes @rails_commands, "turbo:install stimulus:install", "`turbo:install stimulus:install` expected to not be called."

    assert_no_gem "importmap-rails"
    assert_no_gem "jsbundling-rails"
    assert_no_node_files

    assert_file "config/initializers/content_security_policy.rb" do |content|
      assert_no_match(/policy\.connect_src/, content)
    end

    assert_file ".gitattributes" do |content|
      assert_no_match(/yarn\.lock/, content)
    end
  end

  def test_webpack_option
    generator([destination_root], javascript: "webpack")

    run_generator_instance

    assert_includes @rails_commands, "javascript:install:webpack", "`javascript:install:webpack` expected to be called, but wasn't."
    assert_gem "jsbundling-rails"
    assert_node_files
  end

  def test_esbuild_option
    generator([destination_root], javascript: "esbuild")

    run_generator_instance

    assert_includes @rails_commands, "javascript:install:esbuild", "`javascript:install:esbuild` expected to be called, but wasn't."
    assert_gem "jsbundling-rails"
    assert_node_files
  end

  def test_esbuild_option_with_javascript_argument
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

  def test_bun_option
    generator([destination_root], javascript: "bun")

    run_generator_instance

    assert_includes @rails_commands, "javascript:install:bun", "`javascript:install:bun` expected to be called, but wasn't."
    assert_gem "jsbundling-rails"
  end

  def test_bun_option_with_javascript_argument
    run_generator [destination_root, "--javascript", "bun"]
    assert_gem "jsbundling-rails"
  end

  def test_bun_option_with_j_argument
    run_generator [destination_root, "-j", "bun"]
    assert_gem "jsbundling-rails"
  end

  def test_bun_option_with_js_argument
    run_generator [destination_root, "--js", "bun"]
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

  def test_hotwire
    generator [destination_root]
    run_generator_instance

    assert_includes @rails_commands, "turbo:install stimulus:install", "`turbo:install stimulus:install` expected to be called, but wasn't."
    assert_gem "turbo-rails"
    assert_gem "stimulus-rails"
    assert_file "app/views/layouts/application.html.erb" do |content|
      assert_match(/data-turbo-track/, content)
    end
  end

  def test_skip_hotwire
    generator [destination_root], ["--skip-hotwire"]
    run_generator_instance

    assert_no_gem "turbo-rails"
    assert_file "app/views/layouts/application.html.erb" do |content|
      assert_no_match(/data-turbo-track/, content)
    end
    assert_no_file "app/javascript/application.js"
  end

  def test_css_option_with_asset_pipeline_tailwind
    generator [destination_root], ["--css=tailwind"]
    run_generator_instance

    assert_includes @rails_commands, "tailwindcss:install", "`tailwindcss:install` expected to be called, but wasn't."
    assert_gem "tailwindcss-rails"
    assert_no_node_files
  end

  def test_css_option_with_tailwind_uses_cssbundling_gem_when_using_node
    run_generator [destination_root, "--css=tailwind", "--javascript=esbuild"]
    assert_gem "cssbundling-rails"
    assert_no_gem "tailwindcss-rails"
  end

  def test_css_option_with_asset_pipeline_sass
    generator [destination_root], ["--css=sass"]
    run_generator_instance

    assert_includes @rails_commands, "dartsass:install", "`dartsass:install` expected to be called, but wasn't."
    assert_gem "dartsass-rails"
    assert_no_node_files
  end

  def test_css_option_with_sass_uses_cssbundling_gem_when_using_node
    run_generator [destination_root, "--css=sass", "--javascript=esbuild"]
    assert_gem "cssbundling-rails"
    assert_no_gem "dartsass-rails"
  end

  def test_css_option_with_cssbundling_gem
    generator [destination_root], ["--css=postcss"]
    run_generator_instance

    assert_includes @rails_commands, "css:install:postcss", "`css:install:postcss` expected to be called, but wasn't."
    assert_gem "cssbundling-rails"
    assert_node_files
  end

  def test_css_option_with_cssbundling_gem_does_not_force_jsbundling_gem
    run_generator [destination_root, "--css=postcss"]
    assert_no_gem "jsbundling-rails"
    assert_gem "importmap-rails"
  end

  def test_default_generator_executes_all_rails_commands
    generator [destination_root]
    run_generator_instance

    expected_commands = [
      "credentials:diff --enroll", "importmap:install", "turbo:install stimulus:install", "solid_cache:install solid_queue:install solid_cable:install"
    ]
    assert_equal expected_commands, @rails_commands
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

    assert_file "Dockerfile" do |content|
      assert_match(/ARG RUBY_VERSION=#{Gem.ruby_version}/, content)
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
      log
      script
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

  def test_apply_rails_template_class_method_runs_bundle_and_after_bundle_callbacks
    run_generator

    FileUtils.cd(destination_root) do
      template = "lib/template.rb"
      File.write(template, "after_bundle { create_file 'after_bundle_callback_ran' }")

      generator_class.no_commands do
        assert_called_on_instance_of(generator_class, :run_bundle) do
          quietly { generator_class.apply_rails_template(template, destination_root) }
        end
      end

      assert_file "after_bundle_callback_ran"
    end
  end

  def test_apply_rails_template_class_method_does_not_add_bundler_platforms
    run_generator

    FileUtils.cd(destination_root) do
      FileUtils.touch("lib/template.rb")

      generator_class.no_commands do
        # There isn't an easy way to access the generator instance in order to
        # assert that we don't run `bundle lock --add-platform`, so the
        # following assertion assumes that the sole call to `bundle_command` is
        # for `bundle install`.
        assert_called_on_instance_of(generator_class, :bundle_command, times: 1) do
          quietly { generator_class.apply_rails_template("lib/template.rb", destination_root) }
        end
      end
    end
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
      assert_match(/config\/deploy\*\.yml/, content)
      assert_match(/\.kamal/, content)
    end
  end

  def test_dockerignore_skip_kamal
    run_generator [destination_root, "--skip-kamal"]

    assert_file ".dockerignore" do |content|
      assert_no_match(/config\/deploy\*\.yml/, content)
      assert_no_match(/\.kamal/, content)
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
    assert_option :skip_brakeman
    assert_option :skip_ci
    assert_option :skip_dev_gems
    assert_option :skip_docker
    assert_option :skip_hotwire
    assert_option :skip_javascript
    assert_option :skip_jbuilder
    assert_option :skip_kamal
    assert_option :skip_rubocop
    assert_option :skip_solid
    assert_option :skip_system_test
    assert_option :skip_thruster
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

  def test_devcontainer_supports_pretend
    run_generator [ destination_root, "--devcontainer", "--pretend" ]

    assert_no_file(".devcontainer/devcontainer.json")
  end

  def test_devcontainer
    run_generator [destination_root, "--devcontainer", "--name=my-app"]

    assert_devcontainer_json_file do |content|
      assert_equal "my_app", content["name"]
      assert_equal "45678", content["containerEnv"]["CAPYBARA_SERVER_PORT"]
      assert_equal "$KAMAL_REGISTRY_PASSWORD", content["containerEnv"]["KAMAL_REGISTRY_PASSWORD"]
      assert_equal "selenium", content["containerEnv"]["SELENIUM_HOST"]
      assert_includes content["features"].keys, "ghcr.io/rails/devcontainer/features/activestorage"
      assert_includes content["features"].keys, "ghcr.io/devcontainers/features/github-cli:1"
      assert_includes content["features"].keys, "ghcr.io/rails/devcontainer/features/sqlite3"
      assert_includes content["features"].keys, "ghcr.io/devcontainers/features/docker-outside-of-docker:1"
      assert_includes(content["forwardPorts"], 3000)
    end
    assert_file(".devcontainer/Dockerfile") do |content|
      assert_match(/ARG RUBY_VERSION=#{RUBY_VERSION}/, content)
      assert_match(/ENV BINDING="0.0.0.0"/, content)
    end
    assert_file("test/application_system_test_case.rb") do |content|
      assert_match(/^    served_by host: "rails-app", port: ENV\["CAPYBARA_SERVER_PORT"\]/, content)
      assert_match(/^    driven_by :selenium, using: :headless_chrome, screen_size: \[ 1400, 1400 \], options: {$/, content)
      assert_match(/^      browser: :remote,$/, content)
      assert_match(/^      url: "http:\/\/\#{ENV\["SELENIUM_HOST"\]}:4444"$/, content)
    end
    assert_compose_file do |compose_config|
      assert_equal "my_app", compose_config["name"]

      expected_rails_app_config = {
        "build" => {
          "context" => "..",
          "dockerfile" => ".devcontainer/Dockerfile"
        },
        "volumes" => ["../..:/workspaces:cached"],
        "command" => "sleep infinity",
        "depends_on" => ["selenium"]
      }

      assert_equal expected_rails_app_config, compose_config["services"]["rails-app"]

      expected_selenium_config = {
        "image" => "selenium/standalone-chromium",
        "restart" => "unless-stopped",
      }

      assert_equal expected_selenium_config, compose_config["services"]["selenium"]
    end
  end

  def test_devcontainer_skip_kamal
    run_generator [destination_root, "--devcontainer", "--name=my-app", "--skip-kamal"]

    assert_devcontainer_json_file do |devcontainer_json|
      assert_not_includes devcontainer_json["features"].keys, "ghcr.io/devcontainers/features/docker-outside-of-docker:1"
      assert_not_includes devcontainer_json["containerEnv"].keys, "KAMAL_REGISTRY_PASSWORD"
    end
  end

  def test_devcontainer_include_redis_skipping_solid
    run_generator [destination_root, "--devcontainer", "--name=my-app", "--skip-solid"]

    assert_devcontainer_json_file do |content|
      assert_equal "redis://redis:6379/1", content["containerEnv"]["REDIS_URL"]
      assert_includes content["forwardPorts"], 6379
    end

    assert_compose_file do |compose_config|
      assert_includes compose_config["services"]["rails-app"]["depends_on"], "redis"

      expected_redis_config = {
        "image" => "valkey/valkey:8",
        "restart" => "unless-stopped",
        "volumes" => ["redis-data:/data"]
      }

      assert_equal expected_redis_config, compose_config["services"]["redis"]
      assert_includes compose_config["volumes"].keys, "redis-data"
    end
  end

  def test_devcontainer_no_redis_skipping_solid_action_cable_and_active_job
    run_generator [ destination_root, "--devcontainer", "--skip-action-cable", "--skip-active-job", "--skip-solid" ]

    assert_compose_file do |compose_config|
      assert_not_includes compose_config["services"]["rails-app"]["depends_on"], "redis"
      assert_nil compose_config["services"]["redis"]
      assert_nil compose_config["volumes"]
    end

    assert_devcontainer_json_file do |content|
      assert_not_includes content["forwardPorts"], 6379
    end
  end

  def test_devcontainer_postgresql
    run_generator [ destination_root, "--devcontainer", "-d", "postgresql" ]

    assert_compose_file do |compose_config|
      assert_includes compose_config["services"]["rails-app"]["depends_on"], "postgres"

      expected_postgres_config = {
        "image" => "postgres:16.1",
        "restart" => "unless-stopped",
        "networks" => ["default"],
        "volumes" => ["postgres-data:/var/lib/postgresql/data"],
        "environment" => {
          "POSTGRES_USER" => "postgres",
          "POSTGRES_PASSWORD" => "postgres"
        }
      }

      assert_equal expected_postgres_config, compose_config["services"]["postgres"]
      assert_includes compose_config["volumes"].keys, "postgres-data"
    end
    assert_devcontainer_json_file do |content|
      assert_equal "postgres", content["containerEnv"]["DB_HOST"]
      assert_includes content["features"].keys, "ghcr.io/rails/devcontainer/features/postgres-client"
      assert_includes content["forwardPorts"], 5432
    end
    assert_file("config/database.yml") do |content|
      assert_match(/host: <%= ENV\["DB_HOST"\] %>/, content)
    end
  end

  def test_devcontainer_postgresql_skip_solid
    # Regression test for #53482
    run_generator [ destination_root, "--devcontainer", "-d", "postgresql", "--skip-solid"]

    assert_file("config/database.yml") do |content|
      assert_no_match("db/queue_migrate", content)
      assert_no_match("db/cache_migrate", content)
      assert_no_match("db/cable_migrate", content)
    end
  end

  def test_devcontainer_mysql
    run_generator [ destination_root, "--devcontainer", "-d", "mysql" ]

    assert_compose_file do |compose_config|
      assert_includes compose_config["services"]["rails-app"]["depends_on"], "mysql"

      expected_mysql_config = {
        "image" => "mysql/mysql-server:8.0",
        "restart" => "unless-stopped",
        "environment" => {
          "MYSQL_ALLOW_EMPTY_PASSWORD" => "true",
          "MYSQL_ROOT_HOST" => "%"
        },
        "volumes" => ["mysql-data:/var/lib/mysql"],
        "networks" => ["default"],
      }

      assert_equal expected_mysql_config, compose_config["services"]["mysql"]
      assert_includes compose_config["volumes"].keys, "mysql-data"
    end
    assert_devcontainer_json_file do |content|
      assert_equal "mysql", content["containerEnv"]["DB_HOST"]
      assert_includes content["features"].keys, "ghcr.io/rails/devcontainer/features/mysql-client"
      assert_includes content["forwardPorts"], 3306
    end
    assert_file("config/database.yml") do |content|
      assert_match(/host: <%= ENV.fetch\("DB_HOST"\) \{ "127.0.0.1" } %>/, content)
    end
  end

  def test_devcontainer_trilogy
    run_generator [ destination_root, "--devcontainer", "-d", "trilogy" ]

    assert_compose_file do |compose_config|
      assert_includes compose_config["services"]["rails-app"]["depends_on"], "mysql"
      expected_mysql_config = {
        "image" => "mysql/mysql-server:8.0",
        "restart" => "unless-stopped",
        "environment" => {
          "MYSQL_ALLOW_EMPTY_PASSWORD" => "true",
          "MYSQL_ROOT_HOST" => "%"
        },
        "volumes" => ["mysql-data:/var/lib/mysql"],
        "networks" => ["default"],
      }

      assert_equal expected_mysql_config, compose_config["services"]["mysql"]
      assert_includes compose_config["volumes"].keys, "mysql-data"
    end
    assert_devcontainer_json_file do |content|
      assert_equal "mysql", content["containerEnv"]["DB_HOST"]
      assert_includes(content["forwardPorts"], 3306)
    end
    assert_file("config/database.yml") do |content|
      assert_match(/host: <%= ENV.fetch\("DB_HOST"\) \{ "127.0.0.1" } %>/, content)
    end
  end

  def test_devcontainer_mariadb_mysql
    run_generator [ destination_root, "--devcontainer", "-d", "mariadb-mysql" ]

    assert_compose_file do |compose_config|
      assert_includes compose_config["services"]["rails-app"]["depends_on"], "mariadb"
      expected_mariadb_config = {
        "image" => "mariadb:10.5",
        "restart" => "unless-stopped",
        "networks" => ["default"],
        "volumes" => ["mariadb-data:/var/lib/mysql"],
        "environment" => {
          "MARIADB_ALLOW_EMPTY_ROOT_PASSWORD" => "true",
        },
      }

      assert_equal expected_mariadb_config, compose_config["services"]["mariadb"]
      assert_includes compose_config["volumes"].keys, "mariadb-data"
    end
    assert_devcontainer_json_file do |content|
      assert_equal "mariadb", content["containerEnv"]["DB_HOST"]
      assert_includes content["features"].keys, "ghcr.io/rails/devcontainer/features/mysql-client"
      assert_includes(content["forwardPorts"], 3306)
    end
    assert_file("config/database.yml") do |content|
      assert_match(/host: <%= ENV.fetch\("DB_HOST"\) \{ "127.0.0.1" } %>/, content)
    end
  end

  def test_devcontainer_mariadb_trilogy
    run_generator [ destination_root, "--devcontainer", "-d", "mariadb-trilogy" ]

    assert_compose_file do |compose_config|
      assert_includes compose_config["services"]["rails-app"]["depends_on"], "mariadb"
      expected_mariadb_config = {
        "image" => "mariadb:10.5",
        "restart" => "unless-stopped",
        "networks" => ["default"],
        "volumes" => ["mariadb-data:/var/lib/mysql"],
        "environment" => {
          "MARIADB_ALLOW_EMPTY_ROOT_PASSWORD" => "true",
        },
      }

      assert_equal expected_mariadb_config, compose_config["services"]["mariadb"]
      assert_includes compose_config["volumes"].keys, "mariadb-data"
    end
    assert_devcontainer_json_file do |content|
      assert_equal "mariadb", content["containerEnv"]["DB_HOST"]
      assert_includes(content["forwardPorts"], 3306)
    end
    assert_file("config/database.yml") do |content|
      assert_match(/host: <%= ENV.fetch\("DB_HOST"\) \{ "127.0.0.1" } %>/, content)
    end
  end

  def test_devcontainer_no_selenium_when_skipping_system_test
    run_generator [ destination_root, "--devcontainer", "--skip-system-test" ]

    assert_compose_file do |compose_config|
      assert_nil compose_config["services"]["rails-app"]["depends_on"]
      assert_not_includes compose_config["services"].keys, "selenium"
    end
    assert_devcontainer_json_file do |content|
      assert_not_includes content["containerEnv"].keys, "SELENIUM_HOST"
      assert_not_includes content["containerEnv"].keys, "CAPYBARA_SERVER_PORT"
    end
  end

  def test_devcontainer_no_feature_when_skipping_active_storage
    run_generator [ destination_root, "--devcontainer", "--skip-active-storage" ]

    assert_devcontainer_json_file do |content|
      assert_nil content["features"]["ghcr.io/rails/devcontainer/features/activestorage"]
    end
  end

  def test_devcontainer_no_depends_on_when_no_dependencies
    run_generator [ destination_root, "--devcontainer", "--minimal" ]

    assert_compose_file do |compose_config|
      assert_not_includes compose_config["services"]["rails-app"].keys, "depends_on"
    end
  end

  def test_devcontainer_adds_node_tooling_when_required
    run_generator [destination_root, "--devcontainer", "--javascript=esbuild"]

    assert_devcontainer_json_file do |devcontainer_config|
      assert_includes devcontainer_config["features"].keys, "ghcr.io/devcontainers/features/node:1"
    end
  end

  def test_devcontainer_does_not_add_node_tooling_when_not_required
    run_generator [destination_root, "--devcontainer"]

    assert_devcontainer_json_file do |devcontainer_config|
      assert_not_includes devcontainer_config["features"].keys, "ghcr.io/devcontainers/features/node:1"
    end
  end

  def test_devcontainer_dev_flag_mounts_local_rails_repo
    run_generator_using_prerelease [ destination_root, "--devcontainer", "--dev" ]

    assert_devcontainer_json_file do |devcontainer_config|
      rails_mount = devcontainer_config["mounts"].sole

      assert_equal "bind", rails_mount["type"]
      assert_equal Rails::Generators::RAILS_DEV_PATH, rails_mount["source"]
      assert_equal Rails::Generators::RAILS_DEV_PATH, rails_mount["target"]
    end
  end

  def test_no_devcontainer_by_default
    run_generator [ destination_root ]

    assert_no_file(".devcontainer/devcontainer.json")
    assert_no_file(".devcontainer/Dockerfile")
    assert_no_file(".devcontainer/compose.yaml")
  end

  private
    def assert_load_defaults
      assert_file "config/application.rb", /\s+config\.load_defaults #{Rails::VERSION::STRING.to_f}/
    end

    def assert_gem_for_active_storage
      assert_file "Gemfile", /^# gem "image_processing"/
    end

    def assert_frameworks_are_not_required_when_active_storage_is_skipped
      super
      assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']action_mailbox\/engine["']/
      assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']action_text\/engine["']/
    end

    def assert_dockerfile_when_active_storage_is_skipped
      assert_file "Dockerfile" do |content|
        assert_no_match(/libvips/, content)
      end
    end

    def assert_gems_when_active_storage_is_skipped
      assert_no_gem "image_processing"
    end

    def assert_gitattributes_does_not_have_schema_file
      assert_file ".gitattributes" do |content|
        assert_no_match(/schema.rb/, content)
      end
    end

    def assert_node_files
      assert_file ".node-version" do |content|
        assert_match %r/\d+\.\d+\.\d+/, content
      end

      assert_file "Dockerfile" do |content|
        assert_match "yarn", content
        assert_match "node-gyp", content
      end
    end

    def assert_no_node_files
      assert_no_file ".node-version"

      assert_file "Dockerfile" do |content|
        assert_no_match "yarn", content
        assert_no_match "node-gyp", content
      end
    end

    def action(*args, &block)
      capture(:stdout) { generator.send(*args, &block) }
    end
end
