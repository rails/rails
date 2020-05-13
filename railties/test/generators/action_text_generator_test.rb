# frozen_string_literal: true

RAILS_ISOLATED_ENGINE = true

require "abstract_unit"
require "minitest/mock"
require "rails/generators"
require "isolation/abstract_unit"
require "rails/generators/test_case"
require "generators/action_text/install/install_generator"

class ActionTextGeneratorTest < Rails::Generators::TestCase
  include ActiveSupport::Testing::Isolation
  tests ActionText::Generators::InstallGenerator

  def setup
    build_app
    Rails.application = ::TestApp::Application
  end

  def teardown
    teardown_app
  end

  def test_generators_install_javascript_dependencies
    yarn_add_called = 0

    Dir.chdir(app_path) do
      js_dependencies_stub = { "trix" => "latest", "@rails/actiontext" => "latest" }
      generator.stub(:js_dependencies, js_dependencies_stub) do
        generator.stub(:rails_command, yarn_add_called += 1, ["app:binstub:yarn"]) do
          quietly { generator.install_javascript_dependencies }
        end
      end

      assert_equal 1, yarn_add_called

      assert_file "package.json" do |content|
        assert_match(/@rails\/actiontext/, content)
        assert_match(/trix/, content)
      end
    end
  end

  def test_generator_append_dependencies_to_package_file
    Dir.chdir(app_path) do
      quietly { generator.append_dependencies_to_package_file }

      assert_file "app/javascript/packs/application.js" do |content|
        assert_match('require("trix")', content)
        assert_match('require("@rails/actiontext")', content)
      end
    end
  end

  def test_generator_raises_a_warning_for_missing_webpack_configuration_for_action_text_install
    original_stdout = $stdout
    $stdout = StringIO.new

    Dir.chdir(app_path) do
      FileUtils.rm_rf("app/javascript/packs/application.js")

      quietly { generator.append_dependencies_to_package_file }

      expected = "WARNING: Action Text can't locate your JavaScript bundle to add its package dependencies."
      generator.append_dependencies_to_package_file
      $stdout.rewind
      assert_match expected, $stdout.read
    end
  ensure
    $stdout = original_stdout
  end

  def test_create_actiontext_files
    Dir.chdir(app_path) do
      quietly { generator.create_actiontext_files }

      assert_file "app/assets/stylesheets/actiontext.scss"
      assert_file "app/views/active_storage/blobs/_blob.html.erb"
    end
  end

  def test_action_text_and_active_storage_migrations
    Dir.chdir(app_path) do
      ENV["DATABASE_URL"] = "sqlite3:db/database_url_db.sqlite3"
      ActiveRecord::Tasks::DatabaseTasks.migrations_paths = ["#{app_path}/db/migrate"]
      quietly { generator.create_migrations }

      assert_migration "db/migrate/create_active_storage_tables.active_storage.rb"
      assert_migration "db/migrate/create_action_text_tables.action_text.rb"
    end
  end
end
