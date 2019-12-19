# frozen_string_literal: true

require "yaml"
require "active_support/encrypted_file"
require "active_support/ordered_options"
require "active_support/core_ext/object/inclusion"
require "active_support/core_ext/module/delegation"

module ActiveSupport
  class EncryptedConfiguration < EncryptedFile
    delegate :[], :fetch, to: :config
    delegate_missing_to :options

    def initialize(config_path:, key_path:, env_key:, raise_if_missing_key:)
      super content_path: config_path, key_path: key_path,
        env_key: env_key, raise_if_missing_key: raise_if_missing_key
    end

    # Allow a config to be started without a file present
    def read
      super
    rescue ActiveSupport::EncryptedFile::MissingContentError
      ""
    end

    def write(contents)
      deserialize(contents)

      super
    end

    def config
      @config ||= deserialize(read).deep_symbolize_keys
    end

    private
      def options
        @options ||= ActiveSupport::InheritableOptions.new(config)
      end

      def deserialize(config)
        YAML.load(config).presence || {}
      end
  end
end
