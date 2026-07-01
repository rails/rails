# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/app/app_generator"
require "rails/generators/rails/authentication/authentication_generator"

class AuthenticationGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def setup
    FileUtils.mkdir_p("#{destination_root}/app/controllers")
    File.write("#{destination_root}/app/controllers/application_controller.rb", <<~RUBY)
      class ApplicationController < ActionController::Base
      end
    RUBY
    FileUtils.mkdir_p("#{destination_root}/test")
    File.write("#{destination_root}/test/test_helper.rb", <<~RUBY)
      require "rails/test_help"
      module ActiveSupport
        class TestCase
        end
      end
    RUBY
    FileUtils.mkdir_p("#{destination_root}/config/environments")
    File.write("#{destination_root}/config/environments/development.rb", <<~RUBY)
      Rails.application.configure do
      end
    RUBY

    copy_gemfile

    copy_routes
  end

  # === Default (passkey + magic link) mode ===

  def test_authentication_generator
    generator([destination_root])

    run_generator_instance

    assert_file "app/models/user.rb" do |content|
      assert_match(/has_passkeys/, content)
      assert_match(/has_many :magic_links/, content)
      assert_no_match(/has_secure_password/, content)
    end
    assert_file "app/models/current.rb"
    assert_file "app/models/session.rb"
    assert_file "app/models/magic_link.rb"

    assert_file "app/controllers/sessions_controller.rb" do |content|
      assert_match(/include ActionPack::Passkeys::Request/, content)
      assert_match(/passkey_authentication_options/, content)
      assert_match(/MagicLinkMailer/, content)
    end
    assert_file "app/controllers/sessions/passkeys_controller.rb" do |content|
      assert_match(/ActionPack::Passkeys::Passkey.authenticate/, content)
    end
    assert_file "app/controllers/sessions/magic_links_controller.rb" do |content|
      assert_match(/MagicLink.consume/, content)
    end
    assert_file "app/controllers/concerns/authentication.rb" do |content|
      assert_match(/Session.find_by/, content)
      assert_match(/session_id/, content)
      assert_match(/pending_authentication/, content)
    end

    assert_no_file "app/controllers/passwords_controller.rb"
    assert_no_file "app/mailers/passwords_mailer.rb"

    assert_file "app/views/sessions/new.html.erb" do |content|
      assert_match(/passkey_sign_in_button/, content)
      assert_match(/authentication_options/, content)
      assert_match(/username webauthn/, content)
      assert_no_match(/password/, content)
    end
    assert_file "app/views/sessions/magic_links/show.html.erb"

    assert_file "app/channels/application_cable/connection.rb" do |content|
      assert_match(/Session.find_by/, content)
    end

    assert_file "app/mailers/magic_link_mailer.rb"
    assert_file "app/views/magic_link_mailer/sign_in.html.erb"
    assert_file "app/views/magic_link_mailer/sign_in.text.erb"

    assert_file "app/controllers/application_controller.rb" do |content|
      class_line, includes_line = content.lines.first(2)

      assert_equal "class ApplicationController < ActionController::Base\n", class_line, "does not affect class definition"
      assert_equal "  include Authentication\n", includes_line, "includes module on first line of class definition"
    end

    assert_file "config/routes.rb" do |content|
      assert_match(/resource :session/, content)
      assert_match(/resource :magic_link/, content)
      assert_match(/resource :passkey/, content)
      assert_match(%r{mount Mailbin::Engine => :mailbin if Rails\.env\.development\?}, content)
    end

    assert_file "config/environments/development.rb" do |content|
      assert_match(/config\.action_mailer\.delivery_method = :mailbin/, content)
    end

    assert_includes @bundle_commands, ["add mailbin --group development", {}, { quiet: true }]

    assert_includes @rails_commands, "generate migration CreateUsers email_address:string!:uniq --force"
    assert_includes @rails_commands, "generate migration CreateSessions user:references ip_address:string user_agent:string --force"
    assert_includes @rails_commands, "generate migration CreateMagicLinks user:references code:string!:uniq expires_at:datetime! --force"

    assert_file "test/models/user_test.rb"
    assert_file "test/fixtures/users.yml" do |content|
      assert_no_match(/password_digest/, content)
    end
    assert_file "test/controllers/sessions_controller_test.rb"
    assert_file "test/controllers/sessions/passkeys_controller_test.rb"
    assert_file "test/controllers/sessions/magic_links_controller_test.rb"
    assert_file "test/mailers/previews/magic_link_mailer_preview.rb"

    assert_file "test/test_helpers/session_test_helper.rb" do |content|
      assert_match(/session_id/, content)
    end
    assert_file "test/test_helpers/webauthn_test_helper.rb"

    assert_file "test/test_helper.rb" do |content|
      assert_match("require_relative \"test_helpers/session_test_helper\"", content)
    end
  end

  # === Password-based mode ===

  def test_authentication_generator_with_password_based_flag
    generator([destination_root], password_based: true)

    run_generator_instance

    assert_file "app/models/user.rb" do |content|
      assert_match(/has_passkeys/, content)
      assert_match(/has_secure_password/, content)
      assert_no_match(/magic_links/, content)
    end
    assert_file "app/models/current.rb"
    assert_file "app/models/session.rb"
    assert_no_file "app/models/magic_link.rb"

    assert_file "app/controllers/sessions_controller.rb" do |content|
      assert_match(/include ActionPack::Passkeys::Request/, content)
      assert_match(/authenticate_by/, content)
    end
    assert_file "app/controllers/sessions/passkeys_controller.rb"
    assert_file "app/controllers/passwords_controller.rb"
    assert_no_file "app/controllers/sessions/magic_links_controller.rb"

    assert_file "app/controllers/concerns/authentication.rb" do |content|
      assert_match(/Session.find_by/, content)
      assert_match(/session_id/, content)
      assert_no_match(/pending_authentication/, content)
    end

    assert_file "app/views/sessions/new.html.erb" do |content|
      assert_match(/passkey_sign_in_button/, content)
      assert_match(/authentication_options/, content)
      assert_match(/password/, content)
      assert_match(/Forgot password/, content)
    end
    assert_file "app/views/passwords/new.html.erb"
    assert_file "app/views/passwords/edit.html.erb"
    assert_no_file "app/views/sessions/magic_links/show.html.erb"

    assert_file "app/channels/application_cable/connection.rb"

    assert_file "Gemfile" do |content|
      assert_match(/\ngem "bcrypt"/, content)
    end

    assert_file "config/routes.rb" do |content|
      assert_match(/resource :session/, content)
      assert_match(/resource :passkey/, content)
      assert_match(/resources :passwords, param: :token, only: \[:new, :create, :edit, :update\]/, content)
    end

    assert_includes @rails_commands, "generate migration CreateUsers email_address:string!:uniq password_digest:string! --force"
    assert_includes @rails_commands, "generate migration CreateSessions user:references ip_address:string user_agent:string --force"

    assert_file "test/models/user_test.rb"
    assert_file "test/fixtures/users.yml" do |content|
      assert_match(/password_digest/, content)
    end
    assert_file "test/controllers/sessions_controller_test.rb"
    assert_file "test/controllers/sessions/passkeys_controller_test.rb"
    assert_file "test/controllers/passwords_controller_test.rb"
    assert_file "test/mailers/previews/passwords_mailer_preview.rb"

    assert_file "test/test_helpers/session_test_helper.rb" do |content|
      assert_match(/session_id/, content)
    end
    assert_file "test/test_helpers/webauthn_test_helper.rb"

    assert_file "test/test_helper.rb" do |content|
      assert_match("require_relative \"test_helpers/session_test_helper\"", content)
    end
  end

  def test_authentication_generator_without_bcrypt_in_gemfile
    File.write("#{destination_root}/Gemfile", File.read("#{destination_root}/Gemfile").sub(/# gem "bcrypt".*\n/, ""))

    generator([destination_root], password_based: true)

    run_generator_instance

    assert_includes @bundle_commands, ["add bcrypt", {}, { quiet: true }]
  end

  def test_authentication_generator_with_api_flag
    generator([destination_root], api: true)

    run_generator_instance

    assert_file "app/models/user.rb"
    assert_file "app/models/current.rb"
    assert_file "app/models/session.rb"
    assert_file "app/models/magic_link.rb"
    assert_file "app/controllers/sessions_controller.rb"
    assert_file "app/controllers/sessions/passkeys_controller.rb"
    assert_file "app/controllers/sessions/magic_links_controller.rb"
    assert_file "app/controllers/concerns/authentication.rb"
    assert_no_file "app/views/sessions/new.html.erb"
    assert_no_file "app/views/sessions/magic_links/show.html.erb"
  end

  def test_authentication_generator_with_api_and_password_based_flags
    generator([destination_root], api: true, password_based: true)

    run_generator_instance

    assert_file "app/models/user.rb"
    assert_file "app/controllers/sessions/passkeys_controller.rb"
    assert_file "app/controllers/passwords_controller.rb"
    assert_no_file "app/views/sessions/new.html.erb"
    assert_no_file "app/views/passwords/new.html.erb"
  end

  def test_create_users_migration_is_skipped_when_user_model_already_exists
    FileUtils.mkdir_p("#{destination_root}/app/models")
    File.write("#{destination_root}/app/models/user.rb", <<~RUBY)
      class User < ApplicationRecord
      end
    RUBY

    generator([destination_root], force: true)

    run_generator_instance

    assert_not_includes @rails_commands, "generate migration CreateUsers email_address:string!:uniq password_digest:string! --force"
    assert_includes @rails_commands, "generate migration CreateSessions user:references ip_address:string user_agent:string --force"

    assert_file "app/models/session.rb"
    assert_file "app/models/current.rb"
    assert_file "app/controllers/sessions_controller.rb"
    assert_file "app/controllers/concerns/authentication.rb"
  end

  def test_model_test_is_skipped_if_test_framework_is_given
    generator([destination_root], ["-t", "rspec"])

    content = run_generator_instance

    assert_match(/rspec \[not found\]/, content)
    assert_no_file "test/models/user_test.rb"
  end

  def mailer_preview_is_skipped_if_test_framework_is_given
    generator([destination_root], ["-t", "rspec"])

    run_generator_instance

    assert_no_file "test/mailers/previews/magic_link_mailer_preview.rb"
  end

  def session_test_helper_is_skipped_if_test_framework_is_given
    generator([destination_root], ["-t", "rspec"])

    run_generator_instance

    assert_no_file "test/test_helpers/session_test_helper.rb"
    assert_file "test/test_helper.rb" do |test_helper_content|
      assert_no_match(/session_test_helper/, test_helper_content)
      assert_no_match(/SessionTestHelper/, test_helper_content)
    end
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

  def test_authentication_generator_without_action_mailer
    old_value = ActionMailer.const_get(:Railtie)
    ActionMailer.send(:remove_const, :Railtie)
    generator([destination_root])
    run_generator_instance

    assert_no_file "app/mailers/magic_link_mailer.rb"
    assert_no_file "app/views/magic_link_mailer/sign_in.html.erb"
    assert_no_file "app/views/magic_link_mailer/sign_in.text.erb"
    assert_no_file "test/mailers/previews/magic_link_mailer_preview.rb"

    assert_file "app/controllers/sessions_controller.rb" do |content|
      assert_no_match(/MagicLinkMailer/, content)
    end
  ensure
    ActionMailer.const_set(:Railtie, old_value)
  end

  def test_password_based_generator_without_action_mailer
    old_value = ActionMailer.const_get(:Railtie)
    ActionMailer.send(:remove_const, :Railtie)
    generator([destination_root], password_based: true)
    run_generator_instance

    assert_no_file "app/mailers/application_mailer.rb"
    assert_no_file "app/mailers/passwords_mailer.rb"
    assert_no_file "app/views/passwords_mailer/reset.html.erb"
    assert_no_file "app/views/passwords_mailer/reset.text.erb"
    assert_no_file "test/mailers/previews/passwords_mailer_preview.rb"

    assert_file "app/controllers/passwords_controller.rb" do |content|
      assert_no_match(/def create\n    end/, content)
      assert_no_match(/rate_limit/, content)
    end

    assert_file "test/controllers/passwords_controller_test.rb" do |content|
      assert_no_match(/assert_enqueued_email/, content)
    end
  ensure
    ActionMailer.const_set(:Railtie, old_value)
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
