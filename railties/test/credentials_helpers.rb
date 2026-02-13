# frozen_string_literal: true

module CredentialsHelpers
  private
    def write_credentials_override(name, with_key: true)
      Dir.chdir(app_path) do
        FileUtils.mkdir_p "config/credentials"
        File.write "config/credentials/#{name}.key", credentials_key if with_key

        # secret_key_base: secret
        # mystery: revealed
        File.write "config/credentials/#{name}.yml.enc",
          "vgvKu4MBepIgZ5VHQMMPwnQNsLlWD9LKmJHu3UA/8yj6x+3fNhz3DwL9brX7UA==--qLdxHP6e34xeTAiI--nrcAsleXuo9NqiEuhntAhw=="
      end
    end

    def credentials_key
      "2117e775dc2024d4f49ddf3aeb585919"
    end
end
