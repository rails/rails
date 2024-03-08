# frozen_string_literal: true

require "generators/generators_test_helper"
require "generators/action_text/install/install_generator"

class ActionText::Generators::InstallGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  setup do
    Rails.application = Rails.application.class
    Rails.application.config.root = Pathname(destination_root)

    FileUtils.mkdir_p("#{destination_root}/app/javascript")
    FileUtils.touch("#{destination_root}/app/javascript/application.js")

    FileUtils.mkdir_p("#{destination_root}/app/assets/stylesheets")

    FileUtils.mkdir_p("#{destination_root}/config")
    FileUtils.touch("#{destination_root}/config/importmap.rb")
  end

  teardown do
     Rails.application = Rails.application.instance
   end

  test "installs JavaScript dependencies" do
    FileUtils.touch("#{destination_root}/package.json")

    run_generator_instance
    assert_match %r"yarn add trix @rails/actiontext", @run_commands.join("\n")
  end

  test "throws warning for missing entry point" do
    FileUtils.rm("#{destination_root}/app/javascript/application.js")
    assert_match "You must import the @rails/actiontext, trix, and trix/actiontext JavaScript modules", run_generator_instance
  end

  test "imports JavaScript dependencies in application.js" do
    run_generator_instance

    assert_file "app/javascript/application.js" do |content|
      assert_match %r"^#{Regexp.escape 'import "@rails/actiontext"'}", content
      assert_match %r"^#{Regexp.escape 'import "trix"'}", content
      assert_match %r"^#{Regexp.escape 'import "trix/actiontext"'}", content
    end
  end

  test "pins JavaScript dependencies in importmap.rb" do
    run_generator_instance

    assert_file "config/importmap.rb" do |content|
      assert_match %r|pin "@rails/actiontext"|, content
      assert_match %r|pin "trix"|, content
      assert_match %r|pin "trix/actiontext", to: "trix/actiontext.esm.js"|, content
    end
  end

  test "creates Action Text stylesheet" do
    run_generator_instance
    assert_file "app/assets/stylesheets/actiontext.css" do |content|
      assert_match "*= require trix", content
      assert_match ".trix-content", content
    end
  end

  test "appends @import 'actiontext.css' to base scss file" do
    FileUtils.touch("#{destination_root}/app/assets/stylesheets/application.bootstrap.scss")

    run_generator_instance

    assert_file "app/assets/stylesheets/application.bootstrap.scss" do |content|
      assert_match "@import 'actiontext.css';", content
    end
  end


  test "appends @import 'actiontext.css'; to base css file" do
    FileUtils.touch("#{destination_root}/app/assets/stylesheets/application.postcss.css")

    run_generator_instance

    assert_file "app/assets/stylesheets/application.postcss.css" do |content|
      assert_match "@import 'actiontext.css';", content
    end
  end

  test "throws a warning for missing base (s)css file" do
    assert_match "To use the Action Text editor, you must require 'app/assets/stylesheets/actiontext.css' in your base stylesheet.",
      run_generator_instance
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

  private
    def run_generator_instance
      @run_commands = []
      run_command_stub = -> (command, *) { @run_commands << command }

      generator.stub :run, run_command_stub do
        with_database_configuration { super }
      end
    end
end
