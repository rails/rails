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
    assert_equal "hidden", Rails.app.creds.require(:mystery)

    ENV.delete("MYSTERY")
    Rails.app.creds.reload
    assert_equal "revealed", Rails.app.creds.require(:mystery)
  ensure
    ENV.delete("MYSTERY")
  end

  test "set custom creds that only use envs" do
    write_credentials_override(:production)

    app("production")

    ENV["MYSTERY"] = "hidden"
    Rails.app.creds = ActiveSupport::CombinedConfiguration.new(Rails.app.envs)
    assert_equal "hidden", Rails.app.creds.require(:mystery)

    ENV.delete("MYSTERY")
    Rails.app.creds.reload

    assert_raises(KeyError) do
      Rails.app.creds.require(:mystery)
    end
  ensure
    ENV.delete("MYSTERY")
  end

  test "dotenvs are available only in development mode" do
    write_credentials_override(:development)
    write_credentials_override(:production)
    File.write("#{app_path}/.env", "MYSTERY=dotenv_revealed")

    app("development")

    Rails.env = "development"
    Rails.app.creds = nil
    assert_equal "dotenv_revealed", Rails.app.creds.require(:mystery)

    Rails.env = "production"
    Rails.app.creds = nil
    assert_equal "revealed", Rails.app.creds.require(:mystery)
  end
end
