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

  test "printing commands hides hidden commands" do
    class Rails::Command::HiddenCommand < Rails::Command::Base
      desc "command", "Hidden command", hide: true
      def command
      end
    end
    assert_equal [], Rails::Command::HiddenCommand.printing_commands
  end

  test "::executable returns bin and command name" do
    assert_equal "bin/rails generate", Rails::Command::GenerateCommand.executable
  end

  test "::executable integrates subcommand when given" do
    assert_equal "bin/rails generate:help", Rails::Command::GenerateCommand.executable(:help)
  end

  test "::executable integrates ::bin" do
    class Rails::Command::CustomBinCommand < Rails::Command::Base
      self.bin = "FOO"
    end

    assert_equal "FOO custom_bin", Rails::Command::CustomBinCommand.executable
  end

  test "#current_subcommand reflects current subcommand" do
    class Rails::Command::LastSubcommandCommand < Rails::Command::Base
      singleton_class.attr_accessor :last_subcommand

      def set_last_subcommand
        self.class.last_subcommand = current_subcommand
      end

      alias :foo :set_last_subcommand
      alias :bar :set_last_subcommand
    end

    Rails::Command.invoke("last_subcommand:foo")
    assert_equal "foo", Rails::Command::LastSubcommandCommand.last_subcommand

    Rails::Command.invoke("last_subcommand:bar")
    assert_equal "bar", Rails::Command::LastSubcommandCommand.last_subcommand
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
