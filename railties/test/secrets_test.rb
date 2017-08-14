require "abstract_unit"
require "isolation/abstract_unit"
require "rails/generators"
require "rails/generators/rails/encrypted_secrets/encrypted_secrets_generator"
require "rails/secrets"

class Rails::SecretsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
  end

  def teardown
    teardown_app
  end

  test "setting read to false skips parsing" do
    run_secrets_generator do
      Rails::Secrets.new("config/secrets.yml.enc").write(<<-end_of_secrets)
        test:
          yeah_yeah: lets-walk-in-the-cool-evening-light
      end_of_secrets

      Rails.application.config.read_encrypted_secrets = false
      Rails.application.instance_variable_set(:@secrets, nil) # Dance around caching 💃🕺
      assert_not Rails.application.secrets.yeah_yeah
    end
  end

  test "raises when reading secrets without a key" do
    run_secrets_generator do
      FileUtils.rm("config/secrets.yml.key")

      assert_raises Rails::Secrets::MissingKeyError do
        Rails::Secrets.new("config/secrets.yml.enc").key
      end
    end
  end

  test "reading with ENV variable" do
    run_secrets_generator do
      begin
        old_key = ENV["RAILS_MASTER_KEY"]
        ENV["RAILS_MASTER_KEY"] = IO.binread("config/secrets.yml.key").strip
        FileUtils.rm("config/secrets.yml.key")

        assert_match "production:\n#  external_api_key", Rails::Secrets.new("config/secrets.yml.enc").read
      ensure
        ENV["RAILS_MASTER_KEY"] = old_key
      end
    end
  end

  test "reading from key file" do
    run_secrets_generator do
      File.binwrite("config/secrets.yml.key", "00112233445566778899aabbccddeeff")

      assert_equal "00112233445566778899aabbccddeeff", Rails::Secrets.new("config/secrets.yml.enc").key
    end
  end

  test "reading from encrypted file in custom path using key file" do
    run_secrets_generator do
      Rails::Secrets.new("config/secrets.yml.enc").write(<<-end_of_secrets)
        test:
          api_key: "api-key"
      end_of_secrets

      FileUtils.mv("config/secrets.yml.key", "config/secrets-staging.yml.key")
      FileUtils.mv("config/secrets.yml.enc", "config/secrets-staging.yml.enc")

      Rails.application.config.read_encrypted_secrets = "config/secrets-staging.yml.enc"
      Rails.application.instance_variable_set(:@secrets, nil) # Dance around caching 💃🕺

      assert_equal "api-key", Rails.application.secrets.api_key
    end
  end

  test "reading from encrypted file in custom path using ENV variable" do
    run_secrets_generator do
      begin
        old_key = ENV["RAILS_MASTER_KEY"]
        ENV["RAILS_MASTER_KEY"] = IO.binread("config/secrets.yml.key").strip

        Rails::Secrets.new("config/secrets.yml.enc").write(<<-end_of_secrets)
          test:
            api_key: "api-key"
        end_of_secrets

        FileUtils.rm("config/secrets.yml.key")
        FileUtils.mv("config/secrets.yml.enc", "config/secrets-staging.yml.enc")

        Rails.application.config.read_encrypted_secrets = "config/secrets-staging.yml.enc"
        Rails.application.instance_variable_set(:@secrets, nil) # Dance around caching 💃🕺

        assert_equal "api-key", Rails.application.secrets.api_key
      ensure
        ENV["RAILS_MASTER_KEY"] = old_key
      end
    end
  end

  test "editing" do
    run_secrets_generator do
      decrypted_path = nil

      Rails::Secrets.new("config/secrets.yml.enc").read_for_editing do |tmp_path|
        decrypted_path = tmp_path

        assert_match(/production:\n#  external_api_key/, File.read(tmp_path))

        File.write(tmp_path, "Empty streets, empty nights. The Downtown Lights.")
      end

      assert_not File.exist?(decrypted_path)
      assert_equal "Empty streets, empty nights. The Downtown Lights.", Rails::Secrets.new("config/secrets.yml.enc").read
    end
  end

  test "merging secrets with encrypted precedence" do
    run_secrets_generator do
      File.write("config/secrets.yml", <<-end_of_secrets)
        test:
          yeah_yeah: lets-go-walking-down-this-empty-street
      end_of_secrets

      Rails::Secrets.new("config/secrets.yml.enc").write(<<-end_of_secrets)
        test:
          yeah_yeah: lets-walk-in-the-cool-evening-light
      end_of_secrets

      Rails.application.config.read_encrypted_secrets = true
      Rails.application.instance_variable_set(:@secrets, nil) # Dance around caching 💃🕺
      assert_equal "lets-walk-in-the-cool-evening-light", Rails.application.secrets.yeah_yeah
    end
  end

  test "refer secrets inside env config" do
    run_secrets_generator do
      Rails::Secrets.new("config/secrets.yml.enc").write(<<-end_of_yaml)
        production:
          some_secret: yeah yeah
      end_of_yaml

      add_to_env_config "production", <<-end_of_config
        config.dereferenced_secret = Rails.application.secrets.some_secret
      end_of_config

      assert_equal "yeah yeah\n", `bin/rails runner -e production "puts Rails.application.config.dereferenced_secret"`
    end
  end

  test "do not update secrets.yml.enc when secretes do not change" do
    run_secrets_generator do
      Rails::Secrets.new("config/secrets.yml.enc").read_for_editing do |tmp_path|
        File.write(tmp_path, "Empty streets, empty nights. The Downtown Lights.")
      end

      FileUtils.cp("config/secrets.yml.enc", "config/secrets.yml.enc.bk")

      Rails::Secrets.new("config/secrets.yml.enc").read_for_editing do |tmp_path|
        File.write(tmp_path, "Empty streets, empty nights. The Downtown Lights.")
      end

      assert_equal File.read("config/secrets.yml.enc.bk"), File.read("config/secrets.yml.enc")
    end
  end

  test "can read secrets written in binary" do
    run_secrets_generator do
      secrets_template = <<-end_of_secrets
        production:
          api_key: 00112233445566778899aabbccddeeff…
      end_of_secrets

      secrets = Rails::Secrets.new("config/secrets.yml.enc")
      secrets.write(secrets_template.force_encoding(Encoding::ASCII_8BIT))

      secrets.read_for_editing do |tmp_path|
        assert_match(/production:\n\s*api_key: 00112233445566778899aabbccddeeff…\n/, File.read(tmp_path))
      end

      assert_equal "00112233445566778899aabbccddeeff…\n", `bin/rails runner -e production "puts Rails.application.secrets.api_key"`
    end
  end

  test "can read secrets written in non-binary" do
    run_secrets_generator do
      secrets_template = <<-end_of_secrets
        production:
          api_key: 00112233445566778899aabbccddeeff…
      end_of_secrets

      secrets = Rails::Secrets.new("config/secrets.yml.enc")
      secrets.write(secrets_template)

      secrets.read_for_editing do |tmp_path|
        assert_equal(secrets_template.force_encoding(Encoding::ASCII_8BIT), IO.binread(tmp_path))
      end

      assert_equal "00112233445566778899aabbccddeeff…\n", `bin/rails runner -e production "puts Rails.application.secrets.api_key"`
    end
  end

  private
    def run_secrets_generator
      Dir.chdir(app_path) do
        capture(:stdout) do
          Rails::Generators::EncryptedSecretsGenerator.start(["config/secrets.yml.enc"])
        end

        # Make config.paths["config/secrets"] to be relative to app_path
        Rails.application.config.root = app_path

        yield
      end
    end
end
