STATS_DIRECTORIES = [
  %w(Controllers        app/controllers),
  %w(Helpers            app/helpers), 
  %w(Models             app/models),
  %w(Libraries          lib/),
  %w(APIs               app/apis),
  %w(Components         components),
  %w(Integration\ tests test/integration),
  %w(Functional\ tests  test/functional),
  %w(Unit\ tests        test/unit)

].collect { |name, dir| [ name, "#{RAILS_ROOT}/#{dir}" ] }.select { |name, dir| File.directory?(dir) }

desc "Report code statistics (KLOCs, etc) from the application"
task :stats do
  require 'code_statistics'
  CodeStatistics.new(*STATS_DIRECTORIES).to_s
end
