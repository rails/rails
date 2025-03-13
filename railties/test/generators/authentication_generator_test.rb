# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/app/app_generator"
require "rails/generators/rails/authentication/authentication_generator"

class AuthenticationGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def setup
    Rails.application = TestApp::Application
    Rails.application.config.root = Pathname(destination_root)

    self.class.tests Rails::Generators::AppGenerator
    run_generator([destination_root, "--no-skip-bundle"])

    self.class.tests Rails::Generators::AuthenticationGenerator
  end

  def teardown
    Rails.application = Rails.application.instance
  end

  def test_authentication_generator
    run_generator

    assert_file "app/models/user.rb"
    assert_file "app/models/current.rb"
    assert_file "app/models/session.rb"
    assert_file "app/controllers/sessions_controller.rb"
    assert_file "app/controllers/concerns/authentication.rb"
    assert_file "app/views/sessions/new.html.erb"
    assert_file "app/channels/application_cable/connection.rb"

    assert_file "app/controllers/application_controller.rb" do |content|
      class_line, includes_line = content.lines.first(2)

      assert_equal "class ApplicationController < ActionController::Base\n", class_line, "does not affect class definition"
      assert_equal "  include Authentication\n", includes_line, "includes module on first line of class definition"
    end

    assert_file "Gemfile" do |content|
      assert_match(/\ngem "bcrypt"/, content)
    end

    assert_file "config/routes.rb" do |content|
      assert_match(/resource :session/, content)
    end

    assert_migration "db/migrate/create_sessions.rb" do |content|
      assert_match(/t.references :user, null: false, foreign_key: true/, content)
    end

    assert_migration "db/migrate/create_users.rb" do |content|
      assert_match(/t.string :password_digest, null: false/, content)
    end

    assert_file "test/models/user_test.rb"
    assert_file "test/fixtures/users.yml"
  end

  def test_authentication_generator_without_bcrypt_in_gemfile
    File.write("Gemfile", File.read("Gemfile").sub(/# gem "bcrypt".*\n/, ""))

    run_generator_instance

    assert_includes @bundle_commands, ["add bcrypt", {}, { quiet: true }]
  end

  def test_authentication_generator_with_api_flag
    run_generator(["--api"])

    assert_file "app/models/user.rb"
    assert_file "app/models/current.rb"
    assert_file "app/models/session.rb"
    assert_file "app/controllers/sessions_controller.rb"
    assert_file "app/controllers/concerns/authentication.rb"
    assert_no_file "app/views/sessions/new.html.erb"

    assert_file "app/controllers/application_controller.rb" do |content|
      class_line, includes_line = content.lines.first(2)

      assert_equal "class ApplicationController < ActionController::Base\n", class_line, "does not affect class definition"
      assert_equal "  include Authentication\n", includes_line, "includes module on first line of class definition"
    end

    assert_file "Gemfile" do |content|
      assert_match(/\ngem "bcrypt"/, content)
    end

    assert_file "config/routes.rb" do |content|
      assert_match(/resource :session/, content)
    end

    assert_migration "db/migrate/create_sessions.rb" do |content|
      assert_match(/t.references :user, null: false, foreign_key: true/, content)
    end

    assert_migration "db/migrate/create_users.rb" do |content|
      assert_match(/t.string :password_digest, null: false/, content)
    end

    assert_file "test/models/user_test.rb"
    assert_file "test/fixtures/users.yml"
  end

  def test_model_test_is_skipped_if_test_framework_is_given
    content = run_generator ["authentication", "-t", "rspec"]
    assert_match(/rspec \[not found\]/, content)
    assert_no_file "test/models/user_test.rb"
  end

  def test_connection_class_skipped_without_action_cable
    old_value = ActionCable.const_get(:Engine)
    ActionCable.send(:remove_const, :Engine)
    generator([destination_root])
    run_generator_instance

    assert_no_file "app/channels/application_cable/connection.rb"
  ensure
    ActionCable.const_set(:Engine, old_value)
  end

  private
    def run_generator_instance
      @bundle_commands = []
      command_stub ||= -> (command, *args) { @bundle_commands << [command, *args] }

      @rails_commands = []
      @rails_command_stub ||= -> (command, *_) { @rails_commands << command }

      content = nil
      generator.stub(:bundle_command, command_stub) do
        generator.stub(:rails_command, @rails_command_stub) do
          content = super
        end
      end

      content
    end
end
