require "generators/generators_test_helper"
require "rails/generators/rails/encrypted_secrets/encrypted_secrets_generator"

class EncryptedSecretsGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def setup
    super
    cd destination_root
  end

  def test_generates_key_file_and_encrypted_secrets_file
    run_generator

    assert_file "config/secrets.yml.key", /[\w\d]+/

    assert File.exist?("config/secrets.yml.enc")
    assert_no_match(/production:\n  secret_key_base: [\w\d]+/, IO.binread("config/secrets.yml.enc"))
    assert_match(/production:\n  secret_key_base: [\w\d]+/, Rails::Secrets.read)
  end

  def test_appends_to_gitignore
    FileUtils.touch('.gitignore')

    run_generator

    assert_file ".gitignore", /config\/secrets.yml.key/, /(?!config\/secrets.yml.enc)/
  end

  def test_warns_when_ignore_is_missing
    assert_match(/Add this to your ignore file/i, run_generator)
  end
end
