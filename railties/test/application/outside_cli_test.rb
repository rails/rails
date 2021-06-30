# frozen_string_literal: true

RAILS_ISOLATED_ENGINE = true
require "isolation/abstract_unit"

require "rails/gem_version"
require "open3"

# These tests check rails CLI launched outside of the project directory
class OutsideCliTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  test "help command works" do
    output = rails_cli_output("--help")
    assert_match "The 'rails new' command creates a new Rails application", output
  end

  test "help short-cut alias works" do
    output = rails_cli_output("-h")
    assert_match "The 'rails new' command creates a new Rails application", output
  end

  test "invalid command displays help and exits with non-zero status" do
    output, exit_status = rails_cli("some-invalid-command")
    assert_not_equal 0, exit_status
    assert_match "The 'rails new' command creates a new Rails application", output
  end

  test "version command works" do
    output = rails_cli_output("--version")
    assert_equal "Rails #{Rails.gem_version}\n", output
  end

  test "version short-cut alias works" do
    output = rails_cli_output("-v")
    assert_equal "Rails #{Rails.gem_version}\n", output
  end

  def rails_cli(cmd)
    output, status = Open3.capture2("#{rails_executable} #{cmd}")
    [output, status.exitstatus]
  end

  def rails_cli_output(cmd)
    rails_cli(cmd).first
  end
end
