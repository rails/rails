STATS_DIRECTORIES = [
  %w(Helpers           app/helpers), 
  %w(Controllers       app/controllers), 
  %w(APIs              app/apis),
  %w(Components        components),
  %w(Functional\ tests test/functional),
  %w(Models            app/models),
  %w(Unit\ tests       test/unit),
  %w(Libraries         lib/)
].collect { |name, dir| [ name, "#{RAILS_ROOT}/#{dir}" ] }.select { |name, dir| File.directory?(dir) }

desc "Report code statistics (KLOCs, etc) from the application"
task :stats do
  require 'code_statistics'
  CodeStatistics.new(*STATS_DIRECTORIES).to_s
end
