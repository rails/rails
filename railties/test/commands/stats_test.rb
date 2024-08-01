# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::StatsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  setup :build_app
  teardown :teardown_app

  test "`bin/rails stats` handles non-existing directories added by third parties" do
    app_file "config/initializers/custom.rb", <<~CODE
      require "rails/code_statistics"
      ::STATS_DIRECTORIES << ["Non\ Existing", "app/non_existing"]
    CODE

    assert rails "stats"
  end
end
