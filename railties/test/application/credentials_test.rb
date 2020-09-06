# frozen_string_literal: true

require 'isolation/abstract_unit'
require 'env_helpers'

class Rails::CredentialsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation, EnvHelpers

  setup :build_app
  teardown :teardown_app

  test 'reads credentials from environment specific path' do
    write_credentials_override(:production)

    app('production')

    assert_equal 'revealed', Rails.application.credentials.mystery
  end

  test 'reads credentials from customized path and key' do
    write_credentials_override(:staging)
    add_to_env_config('production', "config.credentials.content_path = config.root.join('config/credentials/staging.yml.enc')")
    add_to_env_config('production', "config.credentials.key_path = config.root.join('config/credentials/staging.key')")

    app('production')

    assert_equal 'revealed', Rails.application.credentials.mystery
  end

  test 'reads credentials using environment variable key' do
    write_credentials_override(:production, with_key: false)

    switch_env('RAILS_MASTER_KEY', credentials_key) do
      app('production')

      assert_equal 'revealed', Rails.application.credentials.mystery
    end
  end

  private
    def write_credentials_override(name, with_key: true)
      Dir.chdir(app_path) do
        Dir.mkdir  'config/credentials'
        File.write "config/credentials/#{name}.key", credentials_key if with_key

        # secret_key_base: secret
        # mystery: revealed
        File.write "config/credentials/#{name}.yml.enc",
          'vgvKu4MBepIgZ5VHQMMPwnQNsLlWD9LKmJHu3UA/8yj6x+3fNhz3DwL9brX7UA==--qLdxHP6e34xeTAiI--nrcAsleXuo9NqiEuhntAhw=='
      end
    end

    def credentials_key
      '2117e775dc2024d4f49ddf3aeb585919'
    end
end
