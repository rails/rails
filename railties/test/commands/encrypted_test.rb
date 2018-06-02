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
    run_edit_command("config/tokens.yml.enc", editor: "").tap do |output|
      assert_match "No $EDITOR to open file in", output
      assert_match "bin/rails encrypted:edit", output
    end
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
      assert_match "/config/master.key", File.read(".gitignore")
    end
  end

  test "edit command does not add master key when `RAILS_MASTER_KEY` env specified" do
    Dir.chdir(app_path) do
      key = IO.binread("config/master.key").strip
      FileUtils.rm("config/master.key")

      switch_env("RAILS_MASTER_KEY", key) do
        run_edit_command("config/tokens.yml.enc")
        assert_not File.exist?("config/master.key")
      end
    end
  end

  test "edit encrypts file with custom key" do
    run_edit_command("config/tokens.yml.enc", key: "config/tokens.key")

    Dir.chdir(app_path) do
      assert File.exist?("config/tokens.yml.enc")
      assert File.exist?("config/tokens.key")

      assert_match "/config/tokens.key", File.read(".gitignore")
    end

    assert_match(/access_key_id: 123/, run_edit_command("config/tokens.yml.enc", key: "config/tokens.key"))
  end

  test "show encrypted file with custom key" do
    run_edit_command("config/tokens.yml.enc", key: "config/tokens.key")

    assert_match(/access_key_id: 123/, run_show_command("config/tokens.yml.enc", key: "config/tokens.key"))
  end

  test "show command raise error when require_master_key is specified and key does not exist" do
    add_to_config "config.require_master_key = true"

    assert_match(/Missing encryption key to decrypt file with/,
      run_show_command("config/tokens.yml.enc", key: "unexist.key", allow_failure: true))
  end

  test "show command does not raise error when require_master_key is false and master key does not exist" do
    remove_file "config/master.key"
    add_to_config "config.require_master_key = false"

    assert_match(/Missing 'config\/master\.key' to decrypt data/, run_show_command("config/tokens.yml.enc"))
  end

  test "won't corrupt encrypted file when passed wrong key" do
    run_edit_command("config/tokens.yml.enc", key: "config/tokens.key")

    assert_match "passed the wrong key",
      run_edit_command("config/tokens.yml.enc", allow_failure: true)

    assert_match(/access_key_id: 123/, run_show_command("config/tokens.yml.enc", key: "config/tokens.key"))
  end

  private
    def run_edit_command(file, key: nil, editor: "cat", **options)
      switch_env("EDITOR", editor) do
        rails "encrypted:edit", prepare_args(file, key), **options
      end
    end

    def run_show_command(file, key: nil, **options)
      rails "encrypted:show", prepare_args(file, key), **options
    end

    def prepare_args(file, key)
      args = [ file ]
      args.push("--key", key) if key
      args
    end
end
