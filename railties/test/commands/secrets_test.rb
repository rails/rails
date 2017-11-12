# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "rails/command"
require "rails/commands/secrets/secrets_command"

class Rails::Command::SecretsCommandTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation, EnvHelpers

  setup :build_app
  teardown :teardown_app

  test "edit without editor gives hint" do
    assert_match "No $EDITOR to open decrypted secrets in", run_edit_command(editor: "")
  end

  test "encrypted secrets are deprecated when using credentials" do
    assert_match "Encrypted secrets is deprecated", run_setup_command
    assert_equal 1, $?.exitstatus
    assert_not File.exist?("config/secrets.yml.enc")
  end

  test "encrypted secrets are deprecated when running edit without setup" do
    assert_match "Encrypted secrets is deprecated", run_setup_command
    assert_equal 1, $?.exitstatus
    assert_not File.exist?("config/secrets.yml.enc")
  end

  test "encrypted secrets are deprecated for 5.1 config/secrets.yml apps" do
    Dir.chdir(app_path) do
      FileUtils.rm("config/credentials.yml.enc")
      FileUtils.touch("config/secrets.yml")

      assert_match "Encrypted secrets is deprecated", run_setup_command
      assert_equal 1, $?.exitstatus
      assert_not File.exist?("config/secrets.yml.enc")
    end
  end

  test "edit secrets" do
    prevent_deprecation

    # Run twice to ensure encrypted secrets can be reread after first edit pass.
    2.times do
      assert_match(/external_api_key: 1466aac22e6a869134be3d09b9e89232fc2c2289/, run_edit_command)
    end
  end

  test "show secrets" do
    prevent_deprecation

    assert_match(/external_api_key: 1466aac22e6a869134be3d09b9e89232fc2c2289/, run_show_command)
  end

  private
    def prevent_deprecation
      Dir.chdir(app_path) do
        File.write("config/secrets.yml.key", "f731758c639da2604dfb6bf3d1025de8")
        File.write("config/secrets.yml.enc", "sEB0mHxDbeP1/KdnMk00wyzPFACl9K6t0cZWn5/Mfx/YbTHvnI07vrneqHg9kaH3wOS7L6pIQteu1P077OtE4BSx/ZRc/sgQPHyWu/tXsrfHqnPNpayOF/XZqizE91JacSFItNMWpuPsp9ynbzz+7cGhoB1S4aPNIU6u0doMrzdngDbijsaAFJmsHIQh6t/QHoJx--8aMoE0PvUWmw1Iqz--ldFqnM/K0g9k17M8PKoN/Q==")
      end
    end

    def run_edit_command(editor: "cat")
      switch_env("EDITOR", editor) do
        rails "secrets:edit", allow_failure: true
      end
    end

    def run_show_command
      rails "secrets:show", allow_failure: true
    end

    def run_setup_command
      rails "secrets:setup", allow_failure: true
    end
end
