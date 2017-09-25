# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "rails/command"
require "rails/commands/secrets/secrets_command"

class Rails::Command::SecretsCommandTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation, EnvHelpers

  def setup
    build_app
  end

  def teardown
    teardown_app
  end

  test "edit without editor gives hint" do
    assert_match "No $EDITOR to open decrypted secrets in", run_edit_command(editor: "")
  end

  test "edit secrets" do
    # Runs setup before first edit.
    assert_match(/Adding config\/secrets\.yml\.key to store the encryption key/, run_edit_command)

    # Run twice to ensure encrypted secrets can be reread after first edit pass.
    2.times do
      assert_match(/external_api_key: 1466aac22e6a869134be3d09b9e89232fc2c2289/, run_edit_command)
    end
  end

  test "show secrets" do
    run_setup_command
    assert_match(/external_api_key: 1466aac22e6a869134be3d09b9e89232fc2c2289/, run_show_command)
  end

  private
    def run_edit_command(editor: "cat")
      switch_env("EDITOR", editor) do
        rails "secrets:edit"
      end
    end

    def run_show_command
      rails "secrets:show"
    end

    def run_setup_command
      rails "secrets:setup"
    end
end
