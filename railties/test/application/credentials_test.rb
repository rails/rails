# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class CredentialsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    setup :build_app
    teardown :teardown_app

    test "sets custom application credentials" do
      Dir.chdir(app_path) do
        File.write("config/master.key", ActiveSupport::EncryptedFile.generate_key)

        file = ActiveSupport::EncryptedFile.new(
          content_path: "config/custom-credentials.yml.enc",
          key_path: "config/master.key",
          env_key: "RAILS_MASTER_KEY"
        )

        file.write("aws_access_key_id: secret-key")
      end

      add_to_config <<-RUBY
        config.before_initialize do
          self.credentials = encrypted("config/custom-credentials.yml.enc")
        end
      RUBY

      require "#{app_path}/config/environment"

      assert_equal "secret-key", Rails.application.credentials.aws_access_key_id
    end
  end
end
