# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::HelpIntegrationTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "prints helpful error on unrecognized command" do
    output = rails "vershen", allow_failure: true

    assert_match %(Unrecognized command "vershen"), output
    assert_match "Did you mean?  version", output
  end

  test "prints help via `X:help` command when running `X` and `X:X` command is not defined" do
    help = rails "dev:help"
    output = rails "dev", allow_failure: true

    assert_equal help, output
  end
end
