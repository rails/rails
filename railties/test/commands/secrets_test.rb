require "isolation/abstract_unit"
require "rails/command"
require "rails/commands/secrets/secrets_command"

class Rails::Command::SecretsCommandTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
  end

  def teardown
    teardown_app
  end

  test "edit without editor gives hint" do
    assert_match "No $EDITOR to open decrypted secrets in", run_edit_command(editor: "")
  end

  private
    def run_edit_command(editor: "cat")
      Dir.chdir(app_path) { `EDITOR="#{editor}" bin/rails secrets:edit` }
    end
end
