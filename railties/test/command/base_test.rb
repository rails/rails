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

  test "ARGV is populated" do
    class Rails::Command::ArgvCommand < Rails::Command::Base
      def check_populated(*args)
        raise "not populated" if ARGV.empty? || ARGV != args
      end
    end

    assert_nothing_raised { Rails::Command.invoke("argv:check_populated", %w[foo bar]) }
  end

  test "ARGV is isolated" do
    class Rails::Command::ArgvCommand < Rails::Command::Base
      def check_isolated
        ARGV << "isolate this"
      end
    end

    original_argv = ARGV.dup
    ARGV.clear

    Rails::Command.invoke("argv:check_isolated")
    assert_empty ARGV
  ensure
    ARGV.replace(original_argv)
  end
end
