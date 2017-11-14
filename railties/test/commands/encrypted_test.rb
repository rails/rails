# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "rails/command"
require "rails/commands/encrypted/encrypted_command"

class Rails::Command::EncryptedCommandTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation, EnvHelpers

  setup :build_app
  teardown :teardown_app

  test "edit without editor gives hint" do
    assert_match "No $EDITOR to open file in", run_edit_command("config/tokens.yml.enc", editor: "")
  end

  test "edit encrypted file" do
    # Run twice to ensure file can be reread after first edit pass.
    2.times do
      assert_match(/access_key_id: 123/, run_edit_command("config/tokens.yml.enc"))
    end
  end

  test "edit command does not add master key to gitignore when already exist" do
    run_edit_command("config/tokens.yml.enc")

    Dir.chdir(app_path) do
      gitignore = File.read(".gitignore")
      assert_equal 1, gitignore.scan(%r|config/master\.key|).length
    end
  end

  test "edit encrypts file with custom key" do
    run_edit_command("config/tokens.yml.enc", key: "config/tokens.key")

    Dir.chdir(app_path) do
      assert File.exists?("config/tokens.yml.enc")
      assert File.exists?("config/tokens.key")

      gitignore = File.read(".gitignore")
      assert_equal 1, gitignore.scan(%r|config/tokens\.key|).length
    end

    assert_match(/access_key_id: 123/, run_edit_command("config/tokens.yml.enc", key: "config/tokens.key"))
  end

  test "show encrypted file with custom key" do
    run_edit_command("config/tokens.yml.enc", key: "config/tokens.key")

    assert_match(/access_key_id: 123/, run_show_command("config/tokens.yml.enc", key: "config/tokens.key"))
  end

  private
    def run_edit_command(file, editor: "cat", key: nil)
      args = [file]
      args.push("--key", key) if key

      switch_env("EDITOR", editor) do
        rails "encrypted:edit", args
      end
    end

    def run_show_command(file, key: nil)
      args = [file]
      args.push("--key", key) if key

      rails "encrypted:show", args
    end
end
