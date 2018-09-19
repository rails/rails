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

    def initialize(config_path:, key_path:, env_key:, raise_if_missing_key:,
                   rails_env: nil)
      super content_path: config_path, key_path: key_path,
        env_key: env_key, raise_if_missing_key: raise_if_missing_key
      @rails_env = rails_env
    end

    # Allow a config to be started without a file present
    def read
      super
    rescue ActiveSupport::EncryptedFile::MissingContentError
      ""
    end

    def write(contents)
      deserialize(contents)
      @config = @options = @env = nil # Reinitialize for changed content.

      super
    end

    def config
      @config ||= deserialize(read).deep_symbolize_keys
    end

    class RailsEnv < BasicObject
      delegate :[], :fetch, to: :config
      delegate_missing_to :options

      def initialize(full_config, rails_env)
        @full_config = full_config || {}
        @rails_env = rails_env || ""
      end

      def config
        @config ||= @full_config[@rails_env.to_sym] || {}
      end

      private
        def options
          @options ||= ::ActiveSupport::InheritableOptions.new(config)
        end
    end

    def env
      @env ||= RailsEnv.new(config, @rails_env)
    end

    private
      def options
        @options ||= ActiveSupport::InheritableOptions.new(config)
      end

      def deserialize(config)
        config.present? ? YAML.load(config, content_path) : {}
      end
  end
end
