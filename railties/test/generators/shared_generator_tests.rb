# frozen_string_literal: true

#
# Tests, setup, and teardown common to the application and plugin generator suites.
#
module SharedGeneratorTests
  def setup
    Rails.application = TestApp::Application
    super
    Rails::Generators::AppGenerator.instance_variable_set("@desc", nil)

    Kernel.silence_warnings do
      Thor::Base.shell.attr_accessor :always_force
      @shell = Thor::Base.shell.new
      @shell.always_force = true
    end
  end

  def teardown
    super
    Rails::Generators::AppGenerator.instance_variable_set("@desc", nil)
    Rails.application = TestApp::Application.instance
  end

  def application_path
    destination_root
  end

  def test_skeleton_is_created
    run_generator

    default_files.each { |path| assert_file path }
  end

  def test_plugin_new_generate_pretend
    run_generator ["testapp", "--pretend"]
    default_files.each { |path| assert_no_file File.join("testapp", path) }
  end

  def test_invalid_database_option_raises_an_error
    content = capture(:stderr) { run_generator([destination_root, "-d", "unknown"]) }
    assert_match(/Invalid value for --database option/, content)
  end

  def test_test_files_are_skipped_if_required
    run_generator [destination_root, "--skip-test"]
    assert_no_file "test"
  end

  def test_name_collision_raises_an_error
    reserved_words = %w[application destroy plugin runner test]
    reserved_words.each do |reserved|
      content = capture(:stderr) { run_generator [File.join(destination_root, reserved)] }
      assert_match(/Invalid \w+ name #{reserved}\. Please give a name which does not match one of the reserved rails words: application, destroy, plugin, runner, test\n/, content)
    end
  end

  def test_name_raises_an_error_if_name_already_used_constant
    %w{ String Hash Class Module Set Symbol }.each do |ruby_class|
      content = capture(:stderr) { run_generator [File.join(destination_root, ruby_class)] }
      assert_match(/Invalid \w+ name #{ruby_class}, constant #{ruby_class} is already in use\. Please choose another \w+ name\.\n/, content)
    end
  end

  def test_shebang_is_added_to_rails_file
    run_generator [destination_root, "--ruby", "foo/bar/baz", "--full"]
    assert_file "bin/rails", /#!foo\/bar\/baz/
  end

  def test_shebang_when_is_the_same_as_default_use_env
    run_generator [destination_root, "--ruby", Thor::Util.ruby_command, "--full"]
    assert_file "bin/rails", /#!\/usr\/bin\/env/
  end

  def test_template_raises_an_error_with_invalid_path
    quietly do
      content = capture(:stderr) { run_generator([destination_root, "-m", "non/existent/path"]) }

      assert_match(/The template \[.*\] could not be loaded/, content)
      assert_match(/non\/existent\/path/, content)
    end
  end

  def test_template_is_executed_when_supplied_an_https_path
    path = "https://gist.github.com/josevalim/103208/raw/"
    template = +%{ say "It works!" }
    template.instance_eval "def read; self; end" # Make the string respond to read

    check_open = -> *args do
      assert_equal [ path, "Accept" => "application/x-thor-template" ], args
      template
    end

    generator([destination_root], template: path, skip_webpack_install: true).stub(:open, check_open, template) do
      assert_match(/It works!/, run_generator_instance)
    end
  end

  def test_skip_gemfile
    generator([destination_root], skip_gemfile: true, skip_webpack_install: true)
    run_generator_instance

    assert_empty @bundle_commands
    assert_no_file "Gemfile"
  end

  def test_skip_git
    run_generator [destination_root, "--skip-git", "--full"]
    assert_no_file(".gitignore")
    assert_no_directory(".git")
  end

  def test_skip_keeps
    run_generator [destination_root, "--skip-keeps", "--full"]

    assert_file ".gitignore" do |content|
      assert_no_match(/\.keep/, content)
    end
    assert_directory("app/assets/images")
    assert_no_file("app/models/concerns/.keep")
  end

  def test_default_frameworks_are_required_when_others_are_removed
    run_generator [
      destination_root,
      "--skip-active-record",
      "--skip-active-storage",
      "--skip-action-mailer",
      "--skip-action-mailbox",
      "--skip-action-text",
      "--skip-action-cable",
      "--skip-sprockets"
    ]

    assert_file "#{application_path}/config/application.rb", /^require\s+["']rails["']/
    assert_file "#{application_path}/config/application.rb", /^require\s+["']active_model\/railtie["']/
    assert_file "#{application_path}/config/application.rb", /^require\s+["']active_job\/railtie["']/
    assert_file "#{application_path}/config/application.rb", /^# require\s+["']active_record\/railtie["']/
    assert_file "#{application_path}/config/application.rb", /^# require\s+["']active_storage\/engine["']/
    assert_file "#{application_path}/config/application.rb", /^require\s+["']action_controller\/railtie["']/
    assert_file "#{application_path}/config/application.rb", /^# require\s+["']action_mailer\/railtie["']/
    unless generator_class.name == "Rails::Generators::PluginGenerator"
      assert_file "#{application_path}/config/application.rb", /^# require\s+["']action_mailbox\/engine["']/
      assert_file "#{application_path}/config/application.rb", /^# require\s+["']action_text\/engine["']/
    end
    assert_file "#{application_path}/config/application.rb", /^require\s+["']action_view\/railtie["']/
    assert_file "#{application_path}/config/application.rb", /^# require\s+["']action_cable\/engine["']/
    assert_file "#{application_path}/config/application.rb", /^# require\s+["']sprockets\/railtie["']/
    assert_file "#{application_path}/config/application.rb", /^require\s+["']rails\/test_unit\/railtie["']/
  end

  def test_generator_without_skips
    run_generator
    assert_file "#{application_path}/config/application.rb", /\s+require\s+["']rails\/all["']/
    assert_file "#{application_path}/config/environments/development.rb" do |content|
      assert_match(/config\.action_mailer\.raise_delivery_errors = false/, content)
    end
    assert_file "#{application_path}/config/environments/test.rb" do |content|
      assert_match(/config\.action_mailer\.delivery_method = :test/, content)
    end
    assert_file "#{application_path}/config/environments/production.rb" do |content|
      assert_match(/# config\.action_mailer\.raise_delivery_errors = false/, content)
      assert_match(/^  # config\.require_master_key = true/, content)
    end
  end

  def test_gitignore_when_sqlite3
    run_generator

    assert_file ".gitignore" do |content|
      assert_match(/sqlite3/, content)
    end
  end

  def test_gitignore_when_non_sqlite3_db
    run_generator([destination_root, "-d", "mysql"])

    assert_file ".gitignore" do |content|
      assert_no_match(/sqlite/i, content)
    end
  end

  def test_generator_if_skip_active_record_is_given
    run_generator [destination_root, "--skip-active-record"]
    assert_no_directory "#{application_path}/db/"
    assert_no_file "#{application_path}/config/database.yml"
    assert_no_file "#{application_path}/app/models/application_record.rb"
    assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']active_record\/railtie["']/
    assert_file "test/test_helper.rb" do |helper_content|
      assert_no_match(/fixtures :all/, helper_content)
    end
    assert_file "#{application_path}/bin/setup" do |setup_content|
      assert_no_match(/db:prepare/, setup_content)
    end
    assert_file ".gitignore" do |content|
      assert_no_match(/sqlite/i, content)
    end
  end

  def test_generator_for_active_storage
    run_generator

    unless generator_class.name == "Rails::Generators::PluginGenerator"
      assert_file "#{application_path}/app/javascript/packs/application.js" do |content|
        assert_match(/^import \* as ActiveStorage from "@rails\/activestorage"/, content)
        assert_match(/^ActiveStorage.start\(\)/, content)
      end
    end

    assert_file "#{application_path}/config/environments/development.rb" do |content|
      assert_match(/config\.active_storage/, content)
    end

    assert_file "#{application_path}/config/environments/production.rb" do |content|
      assert_match(/config\.active_storage/, content)
    end

    assert_file "#{application_path}/config/environments/test.rb" do |content|
      assert_match(/config\.active_storage/, content)
    end

    assert_file "#{application_path}/config/storage.yml"
    assert_directory "#{application_path}/storage"
    assert_directory "#{application_path}/tmp/storage"

    assert_file ".gitignore" do |content|
      assert_match(/\/storage\//, content)
    end
  end

  def test_generator_if_skip_active_storage_is_given
    run_generator [destination_root, "--skip-active-storage"]

    assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']active_storage\/engine["']/

    assert_file "#{application_path}/app/javascript/packs/application.js" do |content|
      assert_no_match(/activestorage/, content)
    end

    assert_file "#{application_path}/config/environments/development.rb" do |content|
      assert_no_match(/config\.active_storage/, content)
    end

    assert_file "#{application_path}/config/environments/production.rb" do |content|
      assert_no_match(/config\.active_storage/, content)
    end

    assert_file "#{application_path}/config/environments/test.rb" do |content|
      assert_no_match(/config\.active_storage/, content)
    end

    assert_no_file "#{application_path}/config/storage.yml"
    assert_no_directory "#{application_path}/storage"
    assert_no_directory "#{application_path}/tmp/storage"

    assert_file ".gitignore" do |content|
      assert_no_match(/\/storage\//, content)
    end
  end

  def test_generator_does_not_generate_active_storage_contents_if_skip_active_record_is_given
    run_generator [destination_root, "--skip-active-record"]

    assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']active_storage\/engine["']/

    assert_file "#{application_path}/app/javascript/packs/application.js" do |content|
      assert_no_match(/activestorage/i, content)
    end

    assert_file "#{application_path}/config/environments/development.rb" do |content|
      assert_no_match(/config\.active_storage/, content)
    end

    assert_file "#{application_path}/config/environments/production.rb" do |content|
      assert_no_match(/config\.active_storage/, content)
    end

    assert_file "#{application_path}/config/environments/test.rb" do |content|
      assert_no_match(/config\.active_storage/, content)
    end

    assert_no_file "#{application_path}/config/storage.yml"
    assert_no_directory "#{application_path}/storage"
    assert_no_directory "#{application_path}/tmp/storage"

    assert_file ".gitignore" do |content|
      assert_no_match(/\/storage\//, content)
    end
  end

  def test_generator_if_skip_action_mailer_is_given
    run_generator [destination_root, "--skip-action-mailer"]
    assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']action_mailer\/railtie["']/
    assert_file "#{application_path}/config/environments/development.rb" do |content|
      assert_no_match(/config\.action_mailer/, content)
    end
    assert_file "#{application_path}/config/environments/test.rb" do |content|
      assert_no_match(/config\.action_mailer/, content)
    end
    assert_file "#{application_path}/config/environments/production.rb" do |content|
      assert_no_match(/config\.action_mailer/, content)
    end
    assert_no_directory "#{application_path}/app/mailers"
    assert_no_directory "#{application_path}/test/mailers"
  end

  def test_generator_if_skip_action_cable_is_given
    run_generator [destination_root, "--skip-action-cable"]
    assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']action_cable\/engine["']/
    assert_no_file "#{application_path}/config/cable.yml"
    assert_no_file "#{application_path}/app/javascript/consumer.js"
    assert_no_directory "#{application_path}/app/javascript/channels"
    assert_no_directory "#{application_path}/app/channels"
    assert_file "Gemfile" do |content|
      assert_no_match(/redis/, content)
    end
  end

  def test_generator_if_skip_sprockets_is_given
    run_generator [destination_root, "--skip-sprockets"]

    assert_no_file "#{application_path}/config/initializers/assets.rb"
    assert_no_file "#{application_path}/app/assets/config/manifest.js"
    assert_no_file "#{application_path}/app/assets/stylesheets/application.css"

    assert_file "#{application_path}/config/application.rb", /#\s+require\s+["']sprockets\/railtie["']/

    assert_file "Gemfile" do |content|
      assert_no_match(/sass-rails/, content)
    end

    assert_file "#{application_path}/config/environments/development.rb" do |content|
      assert_no_match(/config\.assets\.debug/, content)
    end

    assert_file "#{application_path}/config/environments/production.rb" do |content|
      assert_no_match(/config\.assets\.digest/, content)
      assert_no_match(/config\.assets\.css_compressor/, content)
      assert_no_match(/config\.assets\.compile/, content)
    end
  end

  def test_generator_for_yarn
    skip "#34009 disabled JS by default for plugins" if generator_class.name == "Rails::Generators::PluginGenerator"
    run_generator
    assert_file "#{application_path}/package.json", /dependencies/
    assert_file "#{application_path}/bin/yarn"
    assert_file "#{application_path}/config/initializers/assets.rb", /node_modules/
  end

  def test_generator_for_yarn_skipped
    run_generator([destination_root, "--skip-javascript"])
    assert_no_file "#{application_path}/package.json"
    assert_no_file "#{application_path}/bin/yarn"

    assert_file "#{application_path}/config/initializers/assets.rb" do |content|
      assert_no_match(/node_modules/, content)
    end
  end

  private
    def run_generator_instance
      @bundle_commands = []
      bundle_command_stub = -> (command, *) { @bundle_commands << command }

      generator.stub(:bundle_command, bundle_command_stub) do
        super
      end
    end
end
