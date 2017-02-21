require "abstract_unit"
require "isolation/abstract_unit"
require "rails/generators"
require "rails/generators/rails/encrypted_secrets/encrypted_secrets_generator"
require "rails/secrets"

class Rails::SecretsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
    Rails::Secrets.read_encrypted_secrets = true

    # Sweep the environment from isolation/abstract_unit.
    @old_key = ENV.delete("RAILS_MASTER_KEY")
    FileUtils.rm("#{app_path}/config/secrets.yml.enc")
  end

  def teardown
    ENV["RAILS_MASTER_KEY"] = @old_key
    teardown_app
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

        assert_match "production:\n#  secret_key_base", Rails::Secrets.read
      ensure
        ENV["RAILS_MASTER_KEY"] = old_key
      end
    end
  end

  test "reading from key file" do
    run_secrets_generator do
      File.open("config/secrets.yml.key", "w") do |file|
        file.puts("How do I know you feel it?".encode("ascii-8bit"))
      end

      assert_equal "How do I know you feel it?", Rails::Secrets.key
    end
  end

  test "editing" do
    run_secrets_generator do
      decrypted_path = nil

      Rails::Secrets.read_for_editing do |tmp_path|
        decrypted_path = tmp_path

        assert_match(/production:\n#  secret_key_base/, File.read(tmp_path))

        File.open(tmp_path, "w") do |file|
          file.puts("Empty streets, empty nights. The Downtown Lights")
        end
      end

      assert_not File.exist?(decrypted_path)
      assert_equal "Empty streets, empty nights. The Downtown Lights\n", Rails::Secrets.read
    end
  end

  private
    def run_secrets_generator
      Dir.chdir(app_path) do
        capture(:stdout) do
          Rails::Generators::EncryptedSecretsGenerator.start
        end

        yield
      end
    end
end
