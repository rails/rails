# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "rails/command"

class Rails::Command::SecretsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation, EnvHelpers

  setup :build_app
  teardown :teardown_app

  test "edit without visual or editor gives hint" do
    assert_match "No $VISUAL or $EDITOR to open file in", run_edit_command(visual: "", editor: "")
  end

  test "edit with visual but not editor does not give hint" do
    assert_no_match "No $VISUAL or $EDITOR to open file in", run_edit_command(visual: "cat", editor: "")
  end

  test "edit with editor but not visual does not give hint" do
    assert_no_match "No $VISUAL or $EDITOR to open file in", run_edit_command(visual: "", editor: "cat")
  end

  test "edit secrets" do
    # Use expected default MessageEncryptor serializer for Rails < 7.1 to be compatible with hardcoded secrets.yml.enc
    add_to_config <<-RUBY
      config.active_support.message_serializer = :marshal
    RUBY

    require "#{app_path}/config/environment"

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

    def run_edit_command(visual: "cat", editor: "cat")
      switch_env("VISUAL", visual) do
        switch_env("EDITOR", editor) do
          rails "secrets:edit", allow_failure: true
        end
      end
    end

    def run_show_command
      rails "secrets:show", allow_failure: true
    end
end
