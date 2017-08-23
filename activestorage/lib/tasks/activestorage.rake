# frozen_string_literal: true

namespace :blob do
  desc "Copy over the Active Storage migration needed to the application"
  task migrations: :environment do
    Rake::Task["railties:install:migrations"].invoke
  end
end
