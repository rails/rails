# frozen_string_literal: true

require "abstract_unit"
require "rails/command"

class Rails::Command::ApplicationTest < ActiveSupport::TestCase
  test "rails new without path prints help" do
    output = run_application_command "new"

    # Doesn't include the default thor error message:
    assert_not output.start_with?("No value provided for required arguments")

    # Includes contents of ~/railties/lib/rails/generators/rails/app/USAGE:
    assert output.include?("The `rails new` command creates a new Rails application with a default
    directory structure and configuration at the path you specify.")
  end

  private
    def run_application_command(*args)
      capture(:stdout) { Rails::Command.invoke(:application, args) }
    end
end
