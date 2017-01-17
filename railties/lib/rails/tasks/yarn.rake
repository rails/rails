namespace :yarn do
  desc "Install all JavaScript dependencies as specified via Yarn"
  task :install do
    system('./bin/yarn install')
  end
end

# Run Yarn prior to Sprockets assets precompilation, so dependencies are available for use.
Rake::Task['assets:precompile'].enhance [ 'yarn:install' ]
