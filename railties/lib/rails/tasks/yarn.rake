# frozen_string_literal: true

namespace :yarn do
  desc "Install all JavaScript dependencies as specified via Yarn"
  task :install do
    system("./bin/yarn install --no-progress --production")
  end
end

# Run Yarn prior to Sprockets assets precompilation, so dependencies are available for use.
if Rake::Task.task_defined?("assets:precompile")
  Rake::Task["assets:precompile"].enhance [ "yarn:install" ]
end
