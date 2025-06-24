# frozen_string_literal: true

require "pathname"
require "rail_inspector/changelog"

module ChangelogFixtures
  def changelog_fixture(name)
    path = Pathname.new(File.expand_path("../fixtures/#{name}", __dir__))

    raise ArgumentError, "#{name} fixture not found" unless path.exist?

    RailInspector::Changelog.new(path, path.read)
  end
end
