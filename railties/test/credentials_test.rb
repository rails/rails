# frozen_string_literal: true

require "isolation/abstract_unit"

class Rails::CredentialsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  setup :build_app
  teardown :teardown_app

  test "reads credentials from environment specific path" do
    with_credentials do |content, key|
      Dir.chdir(app_path) do
        Dir.mkdir("config/credentials")
        File.write("config/credentials/production.yml.enc", content)
        File.write("config/credentials/production.key", key)
      end

      app("production")

      assert_equal "revealed", Rails.application.credentials.mystery
    end
  end

  test "reads credentials from customized path and key" do
    with_credentials do |content, key|
      Dir.chdir(app_path) do
        Dir.mkdir("config/credentials")
        File.write("config/credentials/staging.yml.enc", content)
        File.write("config/credentials/staging.key", key)
      end

      add_to_env_config("production", "config.credentials.content_path = config.root.join('config/credentials/staging.yml.enc')")
      add_to_env_config("production", "config.credentials.key_path = config.root.join('config/credentials/staging.key')")
      app("production")

      assert_equal "revealed", Rails.application.credentials.mystery
    end
  end

  private
    def with_credentials
      key = "2117e775dc2024d4f49ddf3aeb585919"
      # secret_key_base: secret
      # mystery: revealed
      content = "vgvKu4MBepIgZ5VHQMMPwnQNsLlWD9LKmJHu3UA/8yj6x+3fNhz3DwL9brX7UA==--qLdxHP6e34xeTAiI--nrcAsleXuo9NqiEuhntAhw=="
      yield(content, key)
    end
end
