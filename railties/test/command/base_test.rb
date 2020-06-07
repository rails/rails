# frozen_string_literal: true

require "abstract_unit"
require "rails/command"
require "rails/commands/generate/generate_command"
require "rails/commands/secrets/secrets_command"
require "rails/commands/db/system/change/change_command"

class Rails::Command::BaseTest < ActiveSupport::TestCase
  test "printing commands" do
    assert_equal [["generate", ""]], Rails::Command::GenerateCommand.printing_commands
    assert_equal [["secrets:setup", ""], ["secrets:edit", ""], ["secrets:show", ""]], Rails::Command::SecretsCommand.printing_commands
    assert_equal [["db:system:change", ""]], Rails::Command::Db::System::ChangeCommand.printing_commands
  end

  test "ARGV is isolated" do
    class Rails::Command::ArgvCommand < Rails::Command::Base
      def check_isolation
        raise "not isolated" unless ARGV.empty?
        ARGV << "isolate this"
      end
    end

    old_argv = ARGV.dup
    new_argv = ["foo", "bar"]
    ARGV.replace(new_argv)

    Rails::Command.invoke("argv:check_isolation") # should not raise
    assert_equal new_argv, ARGV
  ensure
    ARGV.replace(old_argv)
  end
end
