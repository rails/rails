# Set STATS_DIRECTORIES as empty Array unless already defined
# Needed as the legacy rake task defined STATS_DIRECTORIES here
# and other tasks may subsequently modify it
# and the default directory list is now defined in the CodeMetrics
# library, which hasn't necessarily been loaded, yet,
unless Object.const_defined?(:STATS_DIRECTORIES)
  STATS_DIRECTORIES = []
end
desc "Report code statistics (KLOCs, etc) from the application"
task :stats do
  require 'rails/code_statistics'
  STATS_DIRECTORIES = CodeMetrics::StatsDirectories.new.directories | STATS_DIRECTORIES
  CodeStatistics.new(*STATS_DIRECTORIES).to_s
end
