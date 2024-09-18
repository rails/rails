# frozen_string_literal: true

require "releaser"

root    = File.expand_path("..", __dir__)
version = File.read("#{root}/RAILS_VERSION").strip
releaser = Releaser.new(root, version)

module Announcement
  class Version
    def initialize(version)
      @version, @gem_version = version, Gem::Version.new(version)
    end

    def to_s
      @version
    end

    def previous
      @gem_version.segments[0, 3].tap { |v| v[2] -= 1 }.join(".")
    end

    def major_or_security?
      @gem_version.segments[2].zero? || @gem_version.segments[3].is_a?(Integer)
    end

    def rc?
      @version.include?("rc")
    end
  end
end

task :announce do
  Dir.chdir("pkg/") do
    versions = ENV["VERSIONS"] ? ENV["VERSIONS"].split(",") : [ releaser.version ]
    versions = versions.sort.map { |v| Announcement::Version.new(v) }

    raise "Only valid for patch releases" if versions.any?(&:major_or_security?)

    if versions.any?(&:rc?)
      require "date"
      future_date = Date.today + 5
      future_date += 1 while future_date.saturday? || future_date.sunday?

      github_user = `git config github.user`.chomp
    end

    require "erb"
    template = File.read("../tasks/release_announcement_draft.erb")

    puts ERB.new(template, trim_mode: "<>").result(binding)
  end
end
