# frozen_string_literal: true

require "isolation/abstract_unit"

class HelpTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
  end

  def teardown
    teardown_app
  end

  test "command works" do
    output = rails("help")
    assert_match "The most common rails commands are", output
  end

  test "short-cut alias works" do
    output = rails("-h")
    assert_match "The most common rails commands are", output
    assert_match "In addition to those commands", output
  end

  test "help is the default command when no arguments are passed" do
    output = rails("")
    assert_match "The most common rails commands are", output
    assert_no_match "In addition to those commands", output
  end

  test "outside application root it lists common commands only" do
    output = gem_rails("")
    assert_match "The most common rails commands are", output
    assert_no_match "In addition to those commands", output
  end

  test "outside application root it lists common commands only with help option" do
    output = gem_rails("-h")
    assert_match "The most common rails commands are", output
    assert_no_match "In addition to those commands", output
  end

  def gem_rails(cmd)
    cmd = "#{Gem.ruby} #{RAILS_FRAMEWORK_ROOT}/railties/exe/rails #{cmd}"
    output = `#{cmd}`
    raise "Command #{cmd.inspect} failed. Output:\n#{output}" unless $?.success?
    output
  end
end
