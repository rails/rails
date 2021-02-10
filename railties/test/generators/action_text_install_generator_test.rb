# frozen_string_literal: true

require "generators/generators_test_helper"
require "generators/action_text/install/install_generator"

class ActionText::Generators::InstallGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  setup do
    Rails.application = Rails.application.class
    Rails.application.config.root = Pathname(destination_root)
  end

  teardown do
    Rails.application = Rails.application.instance
  end

  test "creates bin/yarn" do
    run_generator_instance

    assert_file "bin/yarn"
  end

  test "aborts with error message when bin/yarn fails" do
    yarn_command = generator.method(:yarn_command)
    @yarn_command_stub = -> (command, config = {}) do
      yarn_command.call(command, config.merge(env: { "PATH" => "" }))
    end

    error_message = capture(:stderr) do
      assert_aborts { run_generator_instance }
    end

    assert_includes error_message, "Yarn executable was not detected in the system"
  end

  test "installs JavaScript dependencies" do
    run_generator_instance
    yarn_commands = @yarn_commands.join("\n")

    assert_match %r"^add .*@rails/actiontext@", yarn_commands
    assert_match %r"^add .*trix@", yarn_commands
  end

  test "throws warning for incomplete webpacker configuration" do
    output = run_generator_instance
    expected = "WARNING: Action Text can't locate your JavaScript bundle to add its package dependencies."

    assert_match expected, output
  end

  test "loads JavaScript dependencies in application.js" do
    application_js = Pathname("app/javascript/packs/application.js").expand_path(destination_root)
    application_js.dirname.mkpath
    application_js.write("\n")
    run_generator_instance

    assert_file application_js do |content|
      assert_match %r"^#{Regexp.escape 'require("@rails/actiontext")'}", content
      assert_match %r"^#{Regexp.escape 'require("trix")'}", content
    end
  end

  test "creates Action Text stylesheet" do
    run_generator_instance

    assert_file "app/assets/stylesheets/actiontext.scss"
  end

  test "creates Active Storage view partial" do
    run_generator_instance

    assert_file "app/views/active_storage/blobs/_blob.html.erb"
  end

  test "creates Action Text content view layout" do
    run_generator_instance

    assert_file "app/views/layouts/action_text/contents/_content.html.erb"
  end

  test "creates migrations" do
    run_generator_instance

    assert_migration "db/migrate/create_active_storage_tables.active_storage.rb"
    assert_migration "db/migrate/create_action_text_tables.action_text.rb"
  end

  test "#yarn_command runs bin/yarn via Ruby" do
    ran = nil
    run_stub = -> (command, *) { ran = command }

    generator.stub(:run, run_stub) do
      generator.send(:yarn_command, "foo")
    end

    assert_match %r"\S bin/yarn foo$", ran
  end

  private
    def run_generator_instance
      @yarn_commands = []
      @yarn_command_stub ||= -> (command, *) { @yarn_commands << command }

      generator.stub :yarn_command, @yarn_command_stub do
        with_database_configuration { super }
      end
    end

    def assert_aborts
      assert_throws :aborted do
        generator.stub :abort, -> { throw :aborted } do
          yield
        end
      end
    end
end
