# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::StatsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  setup :build_app
  teardown :teardown_app

  test "`bin/rails stats` handles directories added by third parties" do
    app_dir "custom/dir"

    app_file "config/initializers/custom.rb", <<~CODE
      require "rails/code_statistics"
      Rails::CodeStatistics.register_directory("Custom dir", "custom/dir")
    CODE

    output = rails "stats"
    assert_match "Custom dir", output
  end

  test "`bin/rails stats` handles non-existing directories added by third parties" do
    app_file "config/initializers/custom.rb", <<~CODE
      require "rails/code_statistics"
      Rails::CodeStatistics.register_directory("Non Existing", "app/non_existing")
    CODE

    output = rails "stats"
    assert_no_match "Non Existing", output
  end
end
