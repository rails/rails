STATS_DIRECTORIES = [
  %w(Helpers     app/helpers), 
  %w(Controllers app/controllers), 
  %w(APIs        app/apis),
  %w(Components  components),
  %w(Functionals test/functional),
  %w(Models      app/models),
  %w(Units       test/unit)
]

desc "Report code statistics (KLOCs, etc) from the application"
task :stats do
  require 'code_statistics'
  CodeStatistics.new(*STATS_DIRECTORIES).to_s
end
