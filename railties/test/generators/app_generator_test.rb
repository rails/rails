require 'abstract_unit'
require 'generators/generators_test_helper'
require 'rails/generators/rails/app/app_generator'
require 'generators/shared_generator_tests.rb'

DEFAULT_APP_FILES = %w(
  .gitignore
  Gemfile
  Rakefile
  config.ru
  app/controllers
  app/helpers
  app/mailers
  app/models
  app/views/layouts
  config/environments
  config/initializers
  config/locales
  db
  doc
  lib
  lib/tasks
  log
  public/images
  public/javascripts
  public/stylesheets
  script/rails
  test/fixtures
  test/functional
  test/integration
  test/performance
  test/unit
  vendor
  vendor/plugins
  tmp/sessions
  tmp/sockets
  tmp/cache
  tmp/pids
)

class AppGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments [destination_root]
  include SharedGeneratorTests

  def default_files
    ::DEFAULT_APP_FILES
  end

  def test_application_controller_and_layout_files
    run_generator
    assert_file "app/views/layouts/application.html.erb", /stylesheet_link_tag :all/
    assert_no_file "public/stylesheets/application.css"
  end

  def test_invalid_application_name_raises_an_error
    content = capture(:stderr){ run_generator [File.join(destination_root, "43-things")] }
    assert_equal "Invalid application name 43-things. Please give a name which does not start with numbers.\n", content
  end

  def test_invalid_application_name_is_fixed
    run_generator [File.join(destination_root, "things-43")]
    assert_file "things-43/config/environment.rb", /Things43::Application\.initialize!/
    assert_file "things-43/config/application.rb", /^module Things43$/
  end

  def test_application_new_exits_with_non_zero_code_on_invalid_application_name
    # TODO: Suppress the output of this (it's because of a Thor::Error)
    `rails new test`
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

  def test_application_name_is_detected_if_it_exists_and_app_folder_renamed
    app_root       = File.join(destination_root, "myapp")
    app_moved_root = File.join(destination_root, "myapp_moved")

    run_generator [app_root]

    Rails.application.config.root = app_moved_root
    Rails.application.class.stubs(:name).returns("Myapp")
    Rails.application.stubs(:is_a?).returns(Rails::Application)

    FileUtils.mv(app_root, app_moved_root)

    generator = Rails::Generators::AppGenerator.new ["rails"], { :with_dispatchers => true },
                                                               :destination_root => app_moved_root, :shell => @shell
    generator.send(:app_const)
    silence(:stdout){ generator.send(:create_config_files) }
    assert_file "myapp_moved/config/environment.rb", /Myapp::Application\.initialize!/
    assert_file "myapp_moved/config/initializers/session_store.rb", /_myapp_session/
  end

  def test_rails_update_generates_correct_session_key
    app_root = File.join(destination_root, 'myapp')
    run_generator [app_root]

    Rails.application.config.root = app_root
    Rails.application.class.stubs(:name).returns("Myapp")
    Rails.application.stubs(:is_a?).returns(Rails::Application)

    generator = Rails::Generators::AppGenerator.new ["rails"], { :with_dispatchers => true }, :destination_root => app_root, :shell => @shell
    generator.send(:app_const)
    silence(:stdout){ generator.send(:create_config_files) }
    assert_file "myapp/config/initializers/session_store.rb", /_myapp_session/
  end

  def test_application_names_are_not_singularized
    run_generator [File.join(destination_root, "hats")]
    assert_file "hats/config/environment.rb", /Hats::Application\.initialize!/
  end

  def test_config_database_is_added_by_default
    run_generator
    assert_file "config/database.yml", /sqlite3/
    assert_file "Gemfile", /^gem\s+["']sqlite3["']$/
  end

  def test_config_another_database
    run_generator([destination_root, "-d", "mysql"])
    assert_file "config/database.yml", /mysql/
    assert_file "Gemfile", /^gem\s+["']mysql2["']$/
  end

  def test_generator_if_skip_active_record_is_given
    run_generator [destination_root, "--skip-active-record"]
    assert_no_file "config/database.yml"
    assert_file "test/test_helper.rb" do |helper_content|
      assert_no_match /fixtures :all/, helper_content
    end
    assert_file "test/performance/browsing_test.rb"
  end

  def test_active_record_is_removed_from_frameworks_if_skip_active_record_is_given
    run_generator [destination_root, "--skip-active-record"]
    assert_file "config/application.rb", /#\s+require\s+["']active_record\/railtie["']/
  end

  def test_prototype_and_test_unit_are_added_by_default
    run_generator
    assert_file "config/application.rb", /#\s+config\.action_view\.javascript_expansions\[:defaults\]\s+=\s+%w\(jquery rails\)/
    assert_file "public/javascripts/application.js"
    assert_file "public/javascripts/prototype.js"
    assert_file "public/javascripts/rails.js"
    assert_file "public/javascripts/controls.js"
    assert_file "public/javascripts/dragdrop.js"
    assert_file "public/javascripts/effects.js"
    assert_file "test"
  end

  def test_javascript_is_skipped_if_required
    run_generator [destination_root, "--skip-javascript"]
    assert_file "config/application.rb", /^\s+config\.action_view\.javascript_expansions\[:defaults\]\s+=\s+%w\(\)/
    assert_file "public/javascripts/application.js"
    assert_no_file "public/javascripts/prototype.js"
    assert_no_file "public/javascripts/rails.js"
  end

  def test_config_prototype_javascript_library
    run_generator [destination_root, "-j", "prototype"]
    assert_file "config/application.rb", /#\s+config\.action_view\.javascript_expansions\[:defaults\]\s+=\s+%w\(jquery rails\)/
    assert_file "public/javascripts/application.js"
    assert_file "public/javascripts/prototype.js"
    assert_file "public/javascripts/controls.js"
    assert_file "public/javascripts/dragdrop.js"
    assert_file "public/javascripts/effects.js"
    assert_file "public/javascripts/rails.js", /prototype/
  end

  def test_config_jquery_javascript_library
    run_generator [destination_root, "-j", "jquery"]
    assert_file "config/application.rb", /^\s+config\.action_view\.javascript_expansions\[:defaults\]\s+=\s+%w\(jquery rails\)/
    assert_file "public/javascripts/application.js"
    assert_file "public/javascripts/jquery.js"
    assert_file "public/javascripts/rails.js", /jQuery/
  end

  def test_template_from_dir_pwd
    FileUtils.cd(Rails.root)
    assert_match /It works from file!/, run_generator([destination_root, "-m", "lib/template.rb"])
  end

  def test_usage_read_from_file
    File.expects(:read).returns("USAGE FROM FILE")
    assert_equal "USAGE FROM FILE", Rails::Generators::AppGenerator.desc
  end

  def test_default_usage
    File.expects(:exist?).returns(false)
    assert_match /Create rails files for app generator/, Rails::Generators::AppGenerator.desc
  end

  def test_default_namespace
    assert_match "rails:app", Rails::Generators::AppGenerator.namespace
  end

  def test_file_is_added_for_backwards_compatibility
    action :file, 'lib/test_file.rb', 'heres test data'
    assert_file 'lib/test_file.rb', 'heres test data'
  end

  def test_test_unit_is_removed_from_frameworks_if_skip_test_unit_is_given
    run_generator [destination_root, "--skip-test-unit"]
    assert_file "config/application.rb" do |file|
      assert_match /config.generators.test_framework = false/, file
    end
  end

protected

  def action(*args, &block)
    silence(:stdout){ generator.send(*args, &block) }
  end

end

class CustomAppGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  tests Rails::Generators::AppGenerator

  arguments [destination_root]
  include SharedCustomGeneratorTests

protected
  def default_files
    ::DEFAULT_APP_FILES
  end

  def builders_dir
    "app_builders"
  end

  def builder_class
    :AppBuilder
  end

  def action(*args, &block)
    silence(:stdout){ generator.send(*args, &block) }
  end
end
