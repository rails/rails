# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "rails/command"
require "fileutils"

class Rails::Command::CredentialsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation, EnvHelpers

  setup :build_app
  teardown :teardown_app

  test "edit without visual or editor gives hint" do
    run_edit_command(visual: "", editor: "").tap do |output|
      assert_match "No $VISUAL or $EDITOR to open file in", output
      assert_match "rails credentials:edit", output
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

  test "edit credentials" do
    # Run twice to ensure credentials can be reread after first edit pass.
    2.times do
      assert_match DEFAULT_CREDENTIALS_PATTERN, run_edit_command
    end
  end

  test "edit command does not add master key to gitignore when already exist" do
    run_edit_command

    Dir.chdir(app_path) do
      gitignore = File.read(".gitignore")
      assert_equal 1, gitignore.scan(%r|config/master\.key|).length
    end
  end

  test "edit command does not overwrite by default if credentials already exists" do
    write_credentials "foo: bar"
    output = run_edit_command

    assert_match %r/foo: bar/, output
    assert_no_match DEFAULT_CREDENTIALS_PATTERN, output
  end

  test "edit command adds master key" do
    remove_file "config/credentials.yml.enc"
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
    remove_file "config/credentials.yml.enc"
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
      assert_match DEFAULT_CREDENTIALS_PATTERN, run_edit_command
      assert_no_file "config/master.key"
      assert_no_match "config/master.key", read_file(".gitignore")
    end
  end

  test "edit command modifies file specified by environment option" do
    remove_file "config/credentials.yml.enc"

    assert_match DEFAULT_CREDENTIALS_PATTERN, run_edit_command(environment: "production")

    assert_no_file "config/credentials.yml.enc"
    assert_file "config/credentials/production.key"
    assert_file "config/credentials/production.yml.enc"
  end

  test "edit command properly expands environment option" do
    remove_file "config/credentials.yml.enc"

    assert_match DEFAULT_CREDENTIALS_PATTERN, run_edit_command(environment: "prod")

    assert_no_file "config/credentials.yml.enc"
    assert_file "config/credentials/production.key"
    assert_file "config/credentials/production.yml.enc"
  end

  test "edit command omits secret_key_base from generated credentials for dev environment" do
    assert_no_match %r/^\s*secret_key_base: /, run_edit_command(environment: "dev")
    assert_file "config/credentials/development.yml.enc"
  end

  test "edit command omits secret_key_base from generated credentials for test environment" do
    assert_no_match %r/^\s*secret_key_base: /, run_edit_command(environment: "test")
    assert_file "config/credentials/test.yml.enc"
  end

  test "edit command does not raise when an initializer tries to access non-existent credentials" do
    app_file "config/initializers/raise_when_loaded.rb", <<-RUBY
      Rails.application.credentials.missing_key!
    RUBY

    assert_match DEFAULT_CREDENTIALS_PATTERN, run_edit_command(environment: "qa")
  end

  test "edit command generates credentials file when it does not exist" do
    remove_file "config/credentials.yml.enc"

    assert_match DEFAULT_CREDENTIALS_PATTERN, run_edit_command

    assert_file "config/credentials.yml.enc"
  end

  test "edit command can use custom template to generate credentials file" do
    app_file "lib/templates/rails/credentials/credentials.yml.tt", <<~ERB
      provides_secret_key_base: <%= [secret_key_base] == [secret_key_base].compact %>
    ERB
    remove_file "config/credentials.yml.enc"

    assert_match %r/provides_secret_key_base: true/, run_edit_command
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


  test "show credentials" do
    assert_match DEFAULT_CREDENTIALS_PATTERN, run_show_command
  end

  test "show command raises error when require_master_key is specified and key does not exist" do
    remove_file "config/master.key"
    add_to_config "config.require_master_key = true"

    assert_match(/Missing encryption key to decrypt file with/, run_show_command(allow_failure: true))
  end

  test "show command does not raise error when require_master_key is false and master key does not exist" do
    remove_file "config/master.key"
    add_to_config "config.require_master_key = false"

    assert_match(/Missing 'config\/master\.key' to decrypt credentials/, run_show_command)
  end

  test "show command displays content specified by environment option" do
    write_credentials "foo: bar", environment: "production"

    assert_match %r/foo: bar/, run_show_command(environment: "production")
  end

  test "show command properly expands environment option" do
    write_credentials "foo: bar", environment: "production"

    assert_match %r/foo: bar/, run_show_command(environment: "prod")
  end


  test "diff enroll diffing" do
    FileUtils.rm(app_path(".gitattributes"))
    assert_match(/\benrolled project/i, run_diff_command(enroll: true))

    assert_includes File.read(app_path(".gitattributes")), <<~EOM
      config/credentials/*.yml.enc diff=rails_credentials
      config/credentials.yml.enc diff=rails_credentials
    EOM
  end

  test "diff enroll diffing when already enrolled" do
    run_diff_command(enroll: true)

    assert_match(/already enrolled/i, run_diff_command(enroll: true))

    assert_equal 1, File.read(app_path(".gitattributes")).scan("config/credentials.yml.enc").length
  end

  test "diff disenroll diffing" do
    FileUtils.rm(app_path(".gitattributes"))
    run_diff_command(enroll: true)

    assert_match(/\bdisenrolled project/i, run_diff_command(disenroll: true))

    assert_not File.exist?(app_path(".gitattributes"))
  end

  test "diff disenroll diffing with existing .gitattributes" do
    File.write(app_path(".gitattributes"), "foo bar\n")
    run_diff_command(enroll: true)

    run_diff_command(disenroll: true)

    assert_equal("foo bar\n", File.read(app_path(".gitattributes")))
  end

  test "diff disenroll diffing when not enrolled" do
    FileUtils.rm(app_path(".gitattributes"))

    assert_match(/not enrolled/i, run_diff_command(disenroll: true))

    assert_not File.exist?(app_path(".gitattributes"))
  end

  test "running edit after enrolling in diffing sets diff driver" do
    run_diff_command(enroll: true)

    assert_match %r/git diff driver/i, run_edit_command

    Dir.chdir(app_path) do
      assert_equal "bin/rails credentials:diff", `git config --get 'diff.rails_credentials.textconv'`.strip
    end

    assert_no_match %r/git diff driver/i, run_edit_command
  end

  test "diff from git diff left file" do
    run_edit_command(environment: "development")

    assert_match(/access_key_id: 123/, run_diff_command("config/credentials/development.yml.enc"))
  end

  test "diff from git diff right file" do
    run_edit_command(environment: "development")

    content_path = app_path("config", "credentials", "KnAM4a_development.yml.enc")
    File.write(content_path,
      File.read(app_path("config", "credentials", "development.yml.enc")))

    assert_match(/access_key_id: 123/, run_diff_command(content_path))
  end

  test "diff for main credentials" do
    assert_match(/access_key_id: 123/, run_diff_command("config/credentials.yml.enc"))
  end

  test "diff when master key is not available" do
    remove_file "config/master.key"

    raw_content = File.read(app_path("config", "credentials.yml.enc"))
    assert_match(raw_content, run_diff_command("config/credentials.yml.enc"))
  end

  test "diff for custom environment" do
    run_edit_command(environment: "custom")

    assert_match(/access_key_id: 123/, run_diff_command("config/credentials/custom.yml.enc"))
  end

  test "diff for custom environment when key is not available" do
    run_edit_command(environment: "custom")
    remove_file "config/credentials/custom.key"

    raw_content = File.read(app_path("config", "credentials", "custom.yml.enc"))
    assert_match(raw_content, run_diff_command("config/credentials/custom.yml.enc"))
  end

  test "diff returns raw encrypted content when errors occur" do
    run_edit_command(environment: "development")

    content_path = app_path("20190807development.yml.enc")
    encrypted_content = File.read(app_path("config", "credentials", "development.yml.enc"))
    File.write(content_path, encrypted_content + "ruin decryption")

    assert_match(encrypted_content, run_diff_command(content_path))
  end


  test "respects config.credentials.content_path when set in config/application.rb" do
    content_path = "my_secrets/credentials.yml.enc"
    add_to_config "config.credentials.content_path = #{content_path.inspect}"

    assert_credentials_paths content_path, "config/master.key"

    assert_credentials_paths content_path, "config/credentials/production.key", environment: "production"
  end

  test "respects config.credentials.key_path when set in config/application.rb" do
    key_path = "my_secrets/master.key"
    add_to_config "config.credentials.key_path = #{key_path.inspect}"

    assert_credentials_paths "config/credentials.yml.enc", key_path

    assert_credentials_paths "config/credentials/production.yml.enc", key_path, environment: "production"
  end

  test "respects config.credentials.content_path when set in config/environments/*.rb" do
    content_path = "my_secrets/credentials.yml.enc"
    add_to_env_config "production", "config.credentials.content_path = #{content_path.inspect}"

    with_rails_env "production" do
      assert_credentials_paths content_path, "config/master.key"
    end

    assert_credentials_paths content_path, "config/credentials/production.key", environment: "production"
  end

  test "respects config.credentials.key_path when set in config/environments/*.rb" do
    key_path = "my_secrets/master.key"
    add_to_env_config "production", "config.credentials.key_path = #{key_path.inspect}"

    with_rails_env "production" do
      assert_credentials_paths "config/credentials.yml.enc", key_path
    end

    assert_credentials_paths "config/credentials/production.yml.enc", key_path, environment: "production"
  end

  private
    DEFAULT_CREDENTIALS_PATTERN = /access_key_id: 123\n.*secret_key_base: \h{128}\n/m

    def run_edit_command(visual: "cat", editor: "cat", environment: nil, **options)
      switch_env("VISUAL", visual) do
        switch_env("EDITOR", editor) do
          args = environment ? ["--environment", environment] : []
          rails "credentials:edit", args, **options
        end
      end
    end

    def run_show_command(environment: nil, **options)
      args = environment ? ["--environment", environment] : []
      rails "credentials:show", args, **options
    end

    def run_diff_command(path = nil, enroll: nil, disenroll: nil, **options)
      args = [path, ("--enroll" if enroll), ("--disenroll" if disenroll)].compact
      rails "credentials:diff", args, **options
    end

    def write_credentials(content, **options)
      switch_env("CONTENT", content) do
        run_edit_command(visual: %(ruby -e "File.write ARGV[0], ENV['CONTENT']"), **options)
      end
    end

    def assert_credentials_paths(content_path, key_path, environment: nil)
      content = "foo: #{content_path}"
      remove_file content_path
      remove_file key_path

      assert_match "Editing #{content_path}", write_credentials(content, environment: environment)
      assert_file content_path
      assert_file key_path

      assert_match content, run_show_command(environment: environment)

      # Decrypted diffs apply to credentials files in standard locations only.
      if %r"config/credentials(?:/.*)?\.yml\.enc$".match?(content_path)
        assert_match content, run_diff_command(content_path)
      end
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
