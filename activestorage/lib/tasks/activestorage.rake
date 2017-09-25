# frozen_string_literal: true

namespace :active_storage do
  desc "Copy over the migration needed to the application"
  task install: :environment do
    Rake::Task["active_storage:install:migrations"].invoke
  end
end
