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

    copy_gemfile

    copy_routes
  end

  def test_authentication_generator
    generator([destination_root])

    run_generator_instance

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

    assert_includes @rails_commands, "generate migration CreateUsers email_address:string!:uniq password_digest:string! --force"
    assert_includes @rails_commands, "generate migration CreateSessions user:references ip_address:string user_agent:string --force"

    assert_file "test/models/user_test.rb"
    assert_file "test/fixtures/users.yml"
    assert_file "test/controllers/sessions_controller_test.rb"
    assert_file "test/controllers/passwords_controller_test.rb"

    assert_file "test/test_helper.rb" do |content|
      assert_match(/session_test_helper/, content)
      assert_match(/SessionTestHelper/, content)
    end
  end

  def test_authentication_generator_without_bcrypt_in_gemfile
    File.write("#{destination_root}/Gemfile", File.read("#{destination_root}/Gemfile").sub(/# gem "bcrypt".*\n/, ""))

    generator([destination_root])

    run_generator_instance

    assert_includes @bundle_commands, ["add bcrypt", {}, { quiet: true }]
  end

  def test_authentication_generator_with_api_flag
    generator([destination_root], api: true)

    run_generator_instance

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

    assert_includes @rails_commands, "generate migration CreateUsers email_address:string!:uniq password_digest:string! --force"
    assert_includes @rails_commands, "generate migration CreateSessions user:references ip_address:string user_agent:string --force"

    assert_file "test/models/user_test.rb"
    assert_file "test/fixtures/users.yml"

    assert_file "test/test_helper.rb" do |content|
      assert_match(/session_test_helper/, content)
      assert_match(/SessionTestHelper/, content)
    end
  end

  def test_model_test_is_skipped_if_test_framework_is_given
    generator([destination_root], ["-t", "rspec"])

    content = run_generator_instance

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
