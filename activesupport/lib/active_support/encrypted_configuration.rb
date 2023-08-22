# frozen_string_literal: true

require "yaml"
require "active_support/encrypted_file"
require "active_support/ordered_options"
require "active_support/core_ext/object/inclusion"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/module/delegation"

module ActiveSupport
  # = Encrypted Configuration
  #
  # Provides convenience methods on top of EncryptedFile to access values stored
  # as encrypted YAML.
  #
  # Values can be accessed via +Hash+ methods, such as +fetch+ and +dig+, or via
  # dynamic accessor methods, similar to OrderedOptions.
  #
  #   my_config = ActiveSupport::EncryptedConfiguration.new(...)
  #   my_config.read # => "some_secret: 123\nsome_namespace:\n  another_secret: 456"
  #
  #   my_config[:some_secret]
  #   # => 123
  #   my_config.some_secret
  #   # => 123
  #   my_config.dig(:some_namespace, :another_secret)
  #   # => 456
  #   my_config.some_namespace.another_secret
  #   # => 456
  #   my_config.fetch(:foo)
  #   # => KeyError
  #   my_config.foo!
  #   # => KeyError
  #
  class EncryptedConfiguration < EncryptedFile
    class InvalidContentError < RuntimeError
      def initialize(content_path)
        super "Invalid YAML in '#{content_path}'."
      end

      def message
        cause.is_a?(Psych::SyntaxError) ? "#{super}\n\n  #{cause.message}" : super
      end
    end

    delegate_missing_to :options

    def initialize(config_path:, key_path:, env_key:, raise_if_missing_key:)
      super content_path: config_path, key_path: key_path,
        env_key: env_key, raise_if_missing_key: raise_if_missing_key
      @config = nil
      @options = nil
    end

    # Reads the file and returns the decrypted content. See EncryptedFile#read.
    def read
      super
    rescue ActiveSupport::EncryptedFile::MissingContentError
      # Allow a config to be started without a file present
      ""
    end

    def validate! # :nodoc:
      deserialize(read)
    end

    # Returns the decrypted content as a Hash with symbolized keys.
    #
    #   my_config = ActiveSupport::EncryptedConfiguration.new(...)
    #   my_config.read # => "some_secret: 123\nsome_namespace:\n  another_secret: 456"
    #
    #   my_config.config
    #   # => { some_secret: 123, some_namespace: { another_secret: 789 } }
    #
    def config
      @config ||= deserialize(read).deep_symbolize_keys
    end

    def inspect # :nodoc:
      "#<#{self.class.name}:#{'%#016x' % (object_id << 1)}>"
    end

    private
      def deep_transform(hash)
        return hash unless hash.is_a?(Hash)

        h = ActiveSupport::OrderedOptions.new
        hash.each do |k, v|
          h[k] = deep_transform(v)
        end
        h
      end

      def options
        @options ||= deep_transform(config)
      end

      def deserialize(content)
        config = YAML.respond_to?(:unsafe_load) ?
          YAML.unsafe_load(content, filename: content_path) :
          YAML.load(content, filename: content_path)

        config.presence || {}
      rescue Psych::SyntaxError
        raise InvalidContentError.new(content_path)
      end
  end
end
