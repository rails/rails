# while having global constant is not good,
# many 3rd party tools depend on it, like rspec-rails, cucumber-rails, etc
# so if will be removed - deprecation warning is needed
STATS_DIRECTORIES = [
  %w(Controllers        app/controllers),
  %w(Helpers            app/helpers),
  %w(Jobs               app/jobs),
  %w(Models             app/models),
  %w(Mailers            app/mailers),
  %w(Javascripts        app/assets/javascripts),
  %w(Libraries          lib/),
  %w(APIs               app/apis),
  %w(Controller\ tests  test/controllers),
  %w(Helper\ tests      test/helpers),
  %w(Model\ tests       test/models),
  %w(Mailer\ tests      test/mailers),
  %w(Job\ tests      test/jobs),
  %w(Integration\ tests test/integration),
  %w(Functional\ tests\ (old)  test/functional),
  %w(Unit\ tests \ (old)       test/unit)
].collect do |name, dir|
  [ name, "#{File.dirname(Rake.application.rakefile_location)}/#{dir}" ]
end.select { |name, dir| File.directory?(dir) }

desc "Report code statistics (KLOCs, etc) from the application or engine"
task :stats do
  require 'rails/code_statistics'
  CodeStatistics.new(*STATS_DIRECTORIES).to_s
end
