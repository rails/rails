# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/secrets"

class Rails::SecretsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  setup :build_app
  teardown :teardown_app

  test "setting read to false skips parsing" do
    run_secrets_generator do
      Rails::Secrets.write(<<-end_of_secrets)
        production:
          yeah_yeah: lets-walk-in-the-cool-evening-light
      end_of_secrets

      add_to_env_config("production", "config.read_encrypted_secrets = false")
      app("production")

      assert_not Rails.application.secrets.yeah_yeah
    end
  end

  test "raises when reading secrets without a key" do
    run_secrets_generator do
      FileUtils.rm("config/secrets.yml.key")

      assert_raises Rails::Secrets::MissingKeyError do
        Rails::Secrets.key
      end
    end
  end

  test "reading with ENV variable" do
    run_secrets_generator do
      begin
        old_key = ENV["RAILS_MASTER_KEY"]
        ENV["RAILS_MASTER_KEY"] = IO.binread("config/secrets.yml.key").strip
        FileUtils.rm("config/secrets.yml.key")

        assert_match "# production:\n#   external_api_key:", Rails::Secrets.read
      ensure
        ENV["RAILS_MASTER_KEY"] = old_key
      end
    end
  end

  test "reading from key file" do
    run_secrets_generator do
      File.binwrite("config/secrets.yml.key", "00112233445566778899aabbccddeeff")

      assert_equal "00112233445566778899aabbccddeeff", Rails::Secrets.key
    end
  end

  test "editing" do
    run_secrets_generator do
      decrypted_path = nil

      Rails::Secrets.read_for_editing do |tmp_path|
        decrypted_path = tmp_path

        assert_match(/# production:\n#   external_api_key/, File.read(tmp_path))

        File.write(tmp_path, "Empty streets, empty nights. The Downtown Lights.")
      end

      assert_not File.exist?(decrypted_path)
      assert_equal "Empty streets, empty nights. The Downtown Lights.", Rails::Secrets.read
    end
  end

  test "merging secrets with encrypted precedence" do
    run_secrets_generator do
      File.write("config/secrets.yml", <<-end_of_secrets)
        production:
          yeah_yeah: lets-go-walking-down-this-empty-street
      end_of_secrets

      Rails::Secrets.write(<<-end_of_secrets)
        production:
          yeah_yeah: lets-walk-in-the-cool-evening-light
      end_of_secrets

      add_to_env_config("production", "config.read_encrypted_secrets = true")
      app("production")

      assert_equal "lets-walk-in-the-cool-evening-light", Rails.application.secrets.yeah_yeah
    end
  end

  test "refer secrets inside env config" do
    run_secrets_generator do
      Rails::Secrets.write(<<-end_of_yaml)
        production:
          some_secret: yeah yeah
      end_of_yaml

      add_to_env_config "production", <<-end_of_config
        config.dereferenced_secret = Rails.application.secrets.some_secret
      end_of_config

      app("production")

      assert_equal "yeah yeah", Rails.application.config.dereferenced_secret
    end
  end

  test "do not update secrets.yml.enc when secretes do not change" do
    run_secrets_generator do
      Rails::Secrets.read_for_editing do |tmp_path|
        File.write(tmp_path, "Empty streets, empty nights. The Downtown Lights.")
      end

      FileUtils.cp("config/secrets.yml.enc", "config/secrets.yml.enc.bk")

      Rails::Secrets.read_for_editing do |tmp_path|
        File.write(tmp_path, "Empty streets, empty nights. The Downtown Lights.")
      end

      assert_equal File.read("config/secrets.yml.enc.bk"), File.read("config/secrets.yml.enc")
    end
  end

  test "can read secrets written in binary" do
    run_secrets_generator do
      secrets = <<-end_of_secrets
        production:
          api_key: 00112233445566778899aabbccddeeff…
      end_of_secrets

      Rails::Secrets.write(secrets.dup.force_encoding(Encoding::ASCII_8BIT))

      Rails::Secrets.read_for_editing do |tmp_path|
        assert_match(/production:\n\s*api_key: 00112233445566778899aabbccddeeff…\n/, File.read(tmp_path))
      end

      app("production")

      assert_equal "00112233445566778899aabbccddeeff…", Rails.application.secrets.api_key
    end
  end

  test "can read secrets written in non-binary" do
    run_secrets_generator do
      secrets = <<-end_of_secrets
        production:
          api_key: 00112233445566778899aabbccddeeff…
      end_of_secrets

      Rails::Secrets.write(secrets)

      Rails::Secrets.read_for_editing do |tmp_path|
        assert_equal(secrets.dup.force_encoding(Encoding::ASCII_8BIT), IO.binread(tmp_path))
      end

      app("production")

      assert_equal "00112233445566778899aabbccddeeff…", Rails.application.secrets.api_key
    end
  end

  private
    def run_secrets_generator
      Dir.chdir(app_path) do
        File.write("config/secrets.yml.key", "f731758c639da2604dfb6bf3d1025de8")
        File.write("config/secrets.yml.enc", "sEB0mHxDbeP1/KdnMk00wyzPFACl9K6t0cZWn5/Mfx/YbTHvnI07vrneqHg9kaH3wOS7L6pIQteu1P077OtE4BSx/ZRc/sgQPHyWu/tXsrfHqnPNpayOF/XZqizE91JacSFItNMWpuPsp9ynbzz+7cGhoB1S4aPNIU6u0doMrzdngDbijsaAFJmsHIQh6t/QHoJx--8aMoE0PvUWmw1Iqz--ldFqnM/K0g9k17M8PKoN/Q==")

        add_to_config <<-RUBY
          config.read_encrypted_secrets = true
        RUBY

        yield
      end
    end
end
