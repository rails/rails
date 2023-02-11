# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::DockerTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "docker:render renders Dockerfile from config/Dockerfile.erb" do
    app_file "config/Dockerfile.erb", %(<%= "stuff".upcase %>)
    run_render_command
    assert_match "STUFF", read_file("Dockerfile")
  end

  test "docker:render --template specifies the template to render" do
    app_file "tmp/Dockerfile.erb", %(<%= "tmp".upcase %>)
    run_render_command template: "tmp/Dockerfile.erb"
    assert_match "TMP", read_file("Dockerfile")
  end

  test "docker:render --dockerfile specifies the output file" do
    app_file "config/Dockerfile.erb", %(<%= "tmp".upcase %>)
    run_render_command dockerfile: "tmp/Dockerfile"
    assert_match "TMP", read_file("tmp/Dockerfile")
  end

  test "docker:render renders with the :production and :test groups by default" do
    app_file "config/Dockerfile.erb", %(<%= Rails.groups.map(&:to_sym).sort %>)
    run_render_command
    assert_match "[:default, :production, :test]", read_file("Dockerfile")
  end

  test "docker:render --environments affects Rails.groups" do
    app_file "config/Dockerfile.erb", %(<%= Rails.groups.map(&:to_sym).sort %>)
    run_render_command environments: "development,test"
    assert_match "[:default, :development, :test]", read_file("Dockerfile")
  end

  test "docker:render prepends '# syntax =' directive" do
    app_file "config/Dockerfile.erb", "STUFF"
    run_render_command
    assert_match %r"\A# syntax = docker/dockerfile:1\n", read_file("Dockerfile")
  end

  test "docker:render does not prepend '# syntax =' directive when already present" do
    app_file "config/Dockerfile.erb", "# syntax = foo\nSTUFF"
    run_render_command
    assert_match %r/\A# syntax = foo\n/, read_file("Dockerfile")
    assert_no_match "# syntax = docker/dockerfile:1", read_file("Dockerfile")
  end

  test "docker:render inserts 'This file was rendered' message" do
    app_file "config/Dockerfile.erb", "STUFF"
    run_render_command
    assert_match %r/\A(?:#.*\n|\n)*# This file was rendered/, read_file("Dockerfile")
  end

  private
    def run_render_command(template: nil, dockerfile: nil, environments: nil, **options)
      args = []
      args.push("--template", template) if template
      args.push("--dockerfile", dockerfile) if dockerfile
      args.push("--environments", environments) if environments
      rails "docker:render", args, **options
    end

    def read_file(relative)
      File.read(app_path(relative))
    end
end
