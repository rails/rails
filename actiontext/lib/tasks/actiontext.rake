# frozen_string_literal: true

namespace :action_text do
  # Prevent migration installation task from showing up twice.
  Rake::Task["install:migrations"].clear_comments

  desc "Copy over the migration, stylesheet, and JavaScript files"
  task install: %w( environment run_installer copy_migrations )

  task :run_installer do
    installer_template = File.expand_path("../templates/installer.rb", __dir__)
    system "#{RbConfig.ruby} ./bin/rails app:template LOCATION=#{installer_template}"
  end

  task :copy_migrations do
    Rake::Task["active_storage:install:migrations"].invoke
    Rake::Task["railties:install:migrations"].reenable # Otherwise you can't run 2 migration copy tasks in one invocation
    Rake::Task["action_text:install:migrations"].invoke
  end
end
