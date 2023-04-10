# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::DevTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "`bin/rails stats` handles non-existing directories added by third parties" do
    Dir.chdir(app_path) do
      app_file("lib/tasks/custom.rake", <<~CODE
        task stats: "custom:statsetup"
        namespace :custom do
          task statsetup: :environment do
            require "rails/code_statistics"
            ::STATS_DIRECTORIES << ["app/non_existing"]
          end
        end
      CODE
      )
      assert rails "stats"
    end
  end
end
