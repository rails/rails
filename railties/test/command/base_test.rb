# frozen_string_literal: true

require "abstract_unit"
require "rails/command"
require "rails/commands/generate/generate_command"
require "rails/commands/secrets/secrets_command"
require "rails/commands/db/system/change/change_command"

class Rails::Command::BaseTest < ActiveSupport::TestCase
  test "printing commands" do
    assert_equal %w(generate), Rails::Command::GenerateCommand.printing_commands
    assert_equal %w(secrets:setup secrets:edit secrets:show), Rails::Command::SecretsCommand.printing_commands
    assert_equal %w(db:system:change), Rails::Command::Db::System::ChangeCommand.printing_commands
  end
end
