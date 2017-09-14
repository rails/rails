# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "rails/command"
require "rails/commands/credentials/credentials_command"

class Rails::Command::CredentialsCommandTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation, EnvHelpers

  setup { build_app }

  teardown { teardown_app }

  test "edit command does not add master key to gitignore when already exist" do
    run_edit_command

    Dir.chdir(app_path) do
      gitignore = File.read(".gitignore")
      assert_equal 1, gitignore.scan(%r|config/master\.key|).length
    end
  end

  private
    def run_edit_command(editor: "cat")
      switch_env("EDITOR", editor) do
        rails "credentials:edit"
      end
    end
end
