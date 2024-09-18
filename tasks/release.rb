# frozen_string_literal: true

require_relative "../tools/releaser/lib/releaser"

FRAMEWORK_NAMES = Hash.new { |h, k| k.split(/(?<=active|action)/).map(&:capitalize).join(" ") }

root    = File.expand_path("..", __dir__)
version = File.read("#{root}/RAILS_VERSION").strip
releaser = Releaser.new(root, version)

namespace :changelog do
  task :release_summary, [:base_release, :release] do |_, args|
    release_regexp = args[:base_release] ? Regexp.escape(args[:base_release]) : /\d+\.\d+\.\d+/

    puts args[:release]

    Releaser::FRAMEWORKS.each do |fw|
      puts "## #{FRAMEWORK_NAMES[fw]}"
      fname    = File.join fw, "CHANGELOG.md"
      contents = File.readlines fname
      contents.shift
      changes = []
      until contents.first =~ /^## Rails #{release_regexp}.*$/ ||
          contents.first =~ /^Please check.*for previous changes\.$/ ||
          contents.empty?
        changes << contents.shift
      end

      puts changes.join
      puts
    end
  end
end

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
