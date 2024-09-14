# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "rails/command"

class Rails::Command::EncryptedTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation, EnvHelpers

  setup :build_app
  teardown :teardown_app

  setup do
    @encrypted_file = "config/tokens.yml.enc"
  end

  test "edit without visual or editor gives hint" do
    run_edit_command(visual: "", editor: "").tap do |output|
      assert_match "No $VISUAL or $EDITOR to open file in", output
      assert_match "rails encrypted:edit", output
    end
  end

  test "edit with visual but not editor does not give hint" do
    run_edit_command(visual: "cat", editor: "").tap do |output|
      assert_no_match "No $VISUAL or $EDITOR to open file in", output
    end
  end

  test "edit with editor but not visual does not give hint" do
    run_edit_command(visual: "", editor: "cat").tap do |output|
      assert_no_match "No $VISUAL or $EDITOR to open file in", output
    end
  end

  test "edit encrypted file" do
    # Run twice to ensure file can be reread after first edit pass.
    2.times do
      assert_match(/access_key_id: 123/, run_edit_command)
    end
  end

  test "edit command adds master key" do
    remove_file "config/master.key"
    app_file ".gitignore", ""
    run_edit_command

    assert_file "config/master.key"
    assert_match "config/master.key", read_file(".gitignore")
  end

  test "edit command does not overwrite master key file if it already exists" do
    master_key = read_file("config/master.key")
    run_edit_command

    assert_equal master_key, read_file("config/master.key")
  end

  test "edit command does not add duplicate master key entries to gitignore" do
    2.times { run_edit_command }

    assert_equal 1, read_file(".gitignore").scan("config/master.key").length
  end

  test "edit command can add master key when require_master_key is true" do
    remove_file "config/master.key"
    add_to_config "config.require_master_key = true"

    assert_nothing_raised { run_edit_command }
    assert_file "config/master.key"
  end

  test "edit command does not add master key when `RAILS_MASTER_KEY` env specified" do
    master_key = read_file("config/master.key")
    remove_file "config/master.key"
    app_file ".gitignore", ""

    switch_env("RAILS_MASTER_KEY", master_key) do
      run_edit_command
      assert_no_file "config/master.key"
      assert_no_match "config/master.key", read_file(".gitignore")
    end
  end

  test "edit encrypts file with custom key" do
    run_edit_command(key: "config/tokens.key")

    Dir.chdir(app_path) do
      assert File.exist?("config/tokens.key")
      assert_match "/config/tokens.key", File.read(".gitignore")
    end

    assert_match(/access_key_id: 123/, run_edit_command(key: "config/tokens.key"))
  end

  test "edit command does not display save confirmation message if interrupted" do
    assert_match %r/file encrypted and saved/i, run_edit_command

    interrupt_command_process = %(ruby -e "Process.kill 'INT', Process.ppid")
    output = run_edit_command(visual: interrupt_command_process)

    assert_no_match %r/file encrypted and saved/i, output
    assert_match %r/nothing saved/i, output
  end

  test "edit command preserves user's content even if it contains invalid YAML" do
    write_invalid_yaml = %(ruby -e "File.write ARGV[0], 'foo: bar: bad'")

    assert_match %r/WARNING: Invalid YAML/, run_edit_command(visual: write_invalid_yaml)
    assert_match %r/foo: bar: bad/, run_edit_command
  end


  test "show encrypted file with custom key" do
    run_edit_command(key: "config/tokens.key")

    assert_match(/access_key_id: 123/, run_show_command(key: "config/tokens.key"))
  end

  test "show command raise error when require_master_key is specified and key does not exist" do
    add_to_config "config.require_master_key = true"

    assert_match(/Missing encryption key to decrypt file with/,
      run_show_command(key: "unexist.key", allow_failure: true))
  end

  test "show command does not raise error when require_master_key is false and master key does not exist" do
    remove_file "config/master.key"
    add_to_config "config.require_master_key = false"

    assert_match(/Missing 'config\/master\.key' to decrypt data/, run_show_command)
  end

  test "won't corrupt encrypted file when passed wrong key" do
    run_edit_command(key: "config/tokens.key")

    assert_match "passed the wrong key",
      run_edit_command(allow_failure: true)

    assert_match(/access_key_id: 123/, run_show_command(key: "config/tokens.key"))
  end

  test "show command does not raise when an initializer tries to access non-existent credentials" do
    app_file "config/initializers/raise_when_loaded.rb", <<-RUBY
      Rails.application.credentials.missing_key!
    RUBY

    run_edit_command(key: "config/tokens.key")

    assert_match(/access_key_id: 123/, run_show_command(key: "config/tokens.key"))
  end

  private
    def run_edit_command(file = @encrypted_file, key: nil, visual: "cat", editor: "cat", **options)
      switch_env("VISUAL", visual) do
        switch_env("EDITOR", editor) do
          rails "encrypted:edit", prepare_args(file, key), **options
        end
      end
    end

    def run_show_command(file = @encrypted_file, key: nil, **options)
      rails "encrypted:show", prepare_args(file, key), **options
    end

    def prepare_args(file, key)
      args = [ file ]
      args.push("--key", key) if key
      args
    end

    def read_file(relative)
      File.read(app_path(relative))
    end

    def assert_file(relative)
      assert File.exist?(app_path(relative)), "Expected file #{relative.inspect} to exist, but it does not"
    end

    def assert_no_file(relative)
      assert_not File.exist?(app_path(relative)), "Expected file #{relative.inspect} to not exist, but it does"
    end
end
