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

  test "creates migrations" do
    run_generator_instance

    assert_migration "db/migrate/create_active_storage_tables.active_storage.rb"
    assert_migration "db/migrate/create_action_text_tables.action_text.rb"
  end

  private
    def run_generator_instance
      @yarn_commands = []
      yarn_command_stub = -> (command, *) { @yarn_commands << command }

      generator.stub :yarn_command, yarn_command_stub do
        with_database_configuration { super }
      end
    end
end
