require "yaml"
require "active_support/encrypted_file"
require "active_support/core_ext/object/inclusion"

module ActiveSupport
  class EncryptedConfiguration < EncryptedFile
    delegate :dig, :fetch, :[], :[]=, to: :config

    def initialize(config_path:, key_path:, env_key:, serializer: :yaml)
      super content_path: config_path, key_path: key_path, env_key: env_key
      @serializer = validated_serializer(serializer)
    end

    def config
      @config ||= deserialize(read).deep_symbolize_keys
    end

    # Saves the current configuration to file, but won't persist any comments that where there already!
    def save
      write serialize(config)
    end

    private
      # Allow a config to be started without a file present
      def read
        super
      rescue ActiveSupport::EncryptedFile::MissingContentError
        ""
      end

      def serialize(config)
        if config.blank? then "" else
          case @serializer
          when :yaml then YAML.dump(config)
          when :json then JSON.encode(config)
          end
        end
      end

      def deserialize(config)
        if config.blank? then {} else
          case @serializer
          when :yaml then YAML.load(config)
          when :json then JSON.decode(config)
          end
        end
      end

      def validated_serializer(serializer)
        serializer.presence_in(%i( yaml json )) ||
          raise(ArgumentError.new("Unknown serializer: #{serializer}"))
      end
  end
end
