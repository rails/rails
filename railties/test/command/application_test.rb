# frozen_string_literal: true

require "abstract_unit"
require "rails/command"

class Rails::Command::ApplicationTest < ActiveSupport::TestCase
  test "rails new without path prints help" do
    output = capture(:stdout) do
      Rails::Command.invoke(:application, %w[new])
    end

    # Doesn't include the default thor error message:
    assert_not output.start_with?("No value provided for required arguments")

    # Includes contents of ~/railties/lib/rails/generators/rails/app/USAGE:
    assert output.include?("The `rails new` command creates a new Rails application with a default
    directory structure and configuration at the path you specify.")
  end

  test "prints helpful error on unrecognized command" do
    output = capture(:stdout) do
      Rails::Command.invoke("vershen")
    rescue SystemExit
    end

    assert_match %(Unrecognized command "vershen"), output
    assert_match "Did you mean?  version", output
  end

  test "prints help via `X:help` command when running `X` and `X:X` command is not defined" do
    help = capture(:stdout) do
      Rails::Command.invoke("dev:help")
    end

    output = capture(:stdout) do
      Rails::Command.invoke("dev")
    rescue SystemExit
    end

    assert_equal help, output
  end
end
