require "yaml"
require "active_support/encrypted_file"
require "active_support/core_ext/object/inclusion"

module ActiveSupport
  class EncryptedConfiguration < EncryptedFile
    delegate :dig, :fetch, :[], :[]=, to: :config

    def initialize(config_path:, key_path:, env_key:)
      super content_path: config_path, key_path: key_path, env_key: env_key
    end

    # Allow a config to be started without a file present
    def read
      super
    rescue ActiveSupport::EncryptedFile::MissingContentError
      ""
    end

    def config
      @config ||= deserialize(read).deep_symbolize_keys
    end

    # Saves the current configuration to file, but won't persist any comments that where there already!
    def save
      write serialize(config)
    end

    private
      def serialize(config)
        config.present? ? YAML.dump(config) : ""
      end

      def deserialize(config)
        config.present? ? YAML.load(config) : {}
      end
  end
end
