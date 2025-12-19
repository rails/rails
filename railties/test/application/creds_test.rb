# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "credentials_helpers"

class Rails::CredsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation, EnvHelpers, CredentialsHelpers

  setup :build_app
  teardown :teardown_app

  test "reads creds from env before credentials" do
    write_credentials_override(:production)

    app("production")

    ENV["MYSTERY"] = "hidden"
    assert_equal "hidden", Rails.app.creds[:mystery]

    ENV.delete("MYSTERY")
    assert_equal "revealed", Rails.app.creds[:mystery]
  ensure
    ENV.delete("MYSTERY")
  end
end
