# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/app/app_generator"
require "rails/generators/rails/sessions/sessions_generator"

class SessionsGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def setup
    Rails.application = TestApp::Application
    Rails.application.config.root = Pathname(destination_root)
  end

  def teardown
    Rails.application = Rails.application.instance
  end

  def test_session_generator
    self.class.tests Rails::Generators::AppGenerator
    run_generator([destination_root])

    self.class.tests Rails::Generators::SessionsGenerator
    run_generator

    assert_file "app/models/user.rb"
    assert_file "app/models/current.rb"
    assert_file "app/models/session.rb"
    assert_file "app/controllers/sessions_controller.rb"
    assert_file "app/controllers/concerns/authentication.rb"
    assert_file "app/views/sessions/new.html.erb"

    assert_file "app/controllers/application_controller.rb" do |content|
      assert_match(/include Authentication/, content)
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
  end
end
