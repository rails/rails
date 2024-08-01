# frozen_string_literal: true

require "abstract_unit"
require "rails/command"
require "rails/commands/generate/generate_command"
require "rails/commands/notes/notes_command"
require "rails/commands/credentials/credentials_command"
require "rails/commands/db/system/change/change_command"

class Rails::Command::BaseTest < ActiveSupport::TestCase
  test "printing commands returns command and description if present" do
    assert_equal ["generate", ""], Rails::Command::GenerateCommand.printing_commands.first
    assert_equal ["notes", "Show comments in your code annotated with FIXME, OPTIMIZE, and TODO"], Rails::Command::NotesCommand.printing_commands.first
  end

  test "printing commands returns namespaced commands" do
    assert_equal %w(credentials:edit credentials:show credentials:diff), Rails::Command::CredentialsCommand.printing_commands.map(&:first)
    assert_equal %w(db:system:change), Rails::Command::Db::System::ChangeCommand.printing_commands.map(&:first)
  end

  test "printing commands hides hidden commands" do
    class Rails::Command::HiddenCommand < Rails::Command::Base
      desc "command", "Hidden command", hide: true
      def command
      end
    end
    assert_equal [], Rails::Command::HiddenCommand.printing_commands
  end

  test "help shows usage and description" do
    class Rails::Command::HelpfulCommand < Rails::Command::Base
      desc "foo PATH", "description of foo"
      def foo(path); end

      desc "bar [paths...]", "description of bar"
      def bar(*paths); end
    end

    overview = capture(:stdout) do
      Rails::Command::HelpfulCommand.perform("help", [], {})
    end
    assert_match "bin/rails helpful:foo PATH", overview
    assert_match "description of foo", overview
    assert_match "bin/rails helpful:bar [paths...]", overview
    assert_match "description of bar", overview

    foo_help = capture(:stdout) do
      Rails::Command::HelpfulCommand.perform("foo", ["--help"], {})
    end
    assert_match "bin/rails helpful:foo PATH", foo_help
    assert_match "description of foo", foo_help
    assert_no_match "helpful:bar", foo_help

    bar_help = capture(:stdout) do
      Rails::Command::HelpfulCommand.perform("bar", ["--help"], {})
    end
    assert_match "bin/rails helpful:bar [paths...]", bar_help
    assert_match "description of bar", bar_help
    assert_no_match "helpful:foo", bar_help
  end

  test "help usage banner shows full command name" do
    module Rails::Command::Nesting
      class NestedCommand < Rails::Command::Base
        def perform(*); end
        def foo(*); end
      end
    end

    main_help = capture(:stdout) do
      Rails::Command::Nesting::NestedCommand.perform("nested", ["--help"], {})
    end
    assert_match %r"Usage:\s+bin/rails nesting:nested$", main_help

    foo_help = capture(:stdout) do
      Rails::Command::Nesting::NestedCommand.perform("foo", ["--help"], {})
    end
    assert_match %r"Usage:\s+bin/rails nesting:nested:foo$", foo_help
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
