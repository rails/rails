desc "Report code statistics (KLOCs, etc) from the application or engine"
task :stats do
  require 'rails/code_statistics'

  STATS_DIRECTORIES = [
    %w(Controllers        app/controllers),
    %w(Helpers            app/helpers),
    %w(Models             app/models),
    %w(Mailers            app/mailers),
    %w(Javascripts        app/assets/javascripts),
    %w(Libraries          lib/),
    %w(APIs               app/apis),
    %w(Controller\ tests  test/controllers),
    %w(Helper\ tests      test/helpers),
    %w(Model\ tests       test/models),
    %w(Mailer\ tests      test/mailers),
    %w(Integration\ tests test/integration),
    %w(Functional\ tests\ (old)  test/functional),
    %w(Unit\ tests \ (old)       test/unit)
  ].collect { |name, dir| [ name, "#{defined?(ENGINE_PATH)? ENGINE_PATH : Rails.root}/#{dir}" ] }.select { |name, dir| File.directory?(dir) }

  CodeStatistics.new(*STATS_DIRECTORIES).to_s
end