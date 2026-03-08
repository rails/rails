# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "credentials_helpers"

class Rails::CredentialsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation, EnvHelpers, CredentialsHelpers

  setup :build_app
  teardown :teardown_app

  test "reads credentials from environment specific path" do
    write_credentials_override(:production)

    app("production")

    assert_equal "revealed", Rails.application.credentials.mystery
  end

  test "reads credentials from customized path and key" do
    write_credentials_override(:staging)
    add_to_env_config("production", "config.credentials.content_path = config.root.join('config/credentials/staging.yml.enc')")
    add_to_env_config("production", "config.credentials.key_path = config.root.join('config/credentials/staging.key')")

    app("production")

    assert_equal "revealed", Rails.application.credentials.mystery
  end

  test "reads credentials using environment variable key" do
    write_credentials_override(:production, with_key: false)

    switch_env("RAILS_MASTER_KEY", credentials_key) do
      app("production")

      assert_equal "revealed", Rails.application.credentials.mystery
    end
  end
end
