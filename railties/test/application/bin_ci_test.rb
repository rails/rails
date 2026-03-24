# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class BinCiTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    setup :build_app
    teardown :teardown_app

    test "bin/ci exists and is executable with default content" do
      Dir.chdir(app_path) do
        assert File.exist?("bin/ci"), "bin/ci does not exist"
        assert File.executable?("bin/ci"), "bin/ci is not executable"

        content = File.read("config/ci.rb")

        # Parallel group
        assert_match(/group "Checks", parallel: 2/, content)

        # Default steps
        assert_match(/bin\/rubocop/, content)
        assert_match(/bin\/brakeman/, content)
        assert_match(/bin\/bundler-audit/, content)
        assert_match(/"bin\/rails test"$/, content)
        assert_match(/"bin\/rails test:system"$/, content)
        assert_match(/bin\/rails db:seed:replant/, content)

        # Tests sub-group
        assert_match(/group "Tests"/, content)

        # Node-specific steps excluded by default
        assert_no_match(/yarn audit/, content)

        # GitHub signoff is commented
        assert_match(/# .*gh signoff/, content)
      end
    end
  end
end
