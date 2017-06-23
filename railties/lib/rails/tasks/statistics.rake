# While global constants are bad, many 3rd party tools depend on this one (e.g
# rspec-rails & cucumber-rails). It's deprecated and will be removed in Rails 6.0.
STATS_DIRECTORIES = []

desc "Report code statistics (KLOCs, etc) from the application or engine"
task stats: :environment do
  require_relative "../code_statistics"
  require_relative "../code_statistics/helpers"
  require_relative "../code_statistics/registry"

  CodeStatistics::Helpers.eager_loaded_paths.each do |dir|
    CodeStatistics.registry.add(CodeStatistics::Helpers.dir_label(dir), dir) unless dir == "app/assets"
  end

  CodeStatistics.registry.add("JavaScripts", "app/assets/javascripts")
  CodeStatistics.registry.add_tests("Controller tests", "test/controllers")
  CodeStatistics.registry.add_tests("Helper tests", "test/helpers")
  CodeStatistics.registry.add_tests("Model tests", "test/models")
  CodeStatistics.registry.add_tests("Mailer tests", "test/mailers")
  CodeStatistics.registry.add_tests("Job tests", "test/jobs")
  CodeStatistics.registry.add_tests("Integration tests", "test/integration")
  CodeStatistics.registry.add_tests("System tests", "test/system")

  if STATS_DIRECTORIES.any?
    ActiveSupport::Deprecation.warn(<<-MSG.squish)
      Mutating ::STATS_DIRECTORIES and CodeStatistics::TEST_TYPES
      to add custom directories to `rails stats` output is deprecated
      and will be removed in Rails 6.0.

      Please use `CodeStatistics.registry.add` and
      `CodeStatistics.registry.add_tests` instead.
    MSG

    STATS_DIRECTORIES.each do |label, dir|
      if CodeStatistics::TEST_TYPES.include?(label)
        CodeStatistics.registry.add_tests(label, dir)
      else
        CodeStatistics.registry.add(label, dir)
      end
    end
  end

  CodeStatistics.new.to_s
end
