# frozen_string_literal: true

require "thor"

module RailInspector
  class Cli < Thor
    class << self
      def exit_on_failure?
        true
      end
    end

    desc "changelogs RAILS_PATH", "Check CHANGELOG files for common issues"
    def changelogs(rails_path)
      require_relative "./changelog"

      exit Changelog::Runner.new(rails_path).call
    end

    desc "configuration RAILS_PATH", "Check various Configuration issues"
    option :autocorrect, type: :boolean, aliases: :a
    def configuration(rails_path)
      require_relative "./configuring"

      checker = Configuring.new(rails_path)
      checker.check

      puts checker.errors unless checker.errors.empty?
      exit checker.errors.empty? unless options[:autocorrect]

      checker.write!
    end
  end
end
