require "yaml"
require "active_support/message_encryptor"
require "active_support/core_ext/string/strip"

module ActiveSupport
  class EncryptedConfiguration
    class MissingKeyError < RuntimeError
      def initialize(key_path:, env_key:)
        super \
          "Missing encryption key to decrypt configuration with. " +
          "Ask your team for your master key and write it to #{key_path} or put it in the ENV['#{env_key}']."
      end
    end

    CIPHER = "aes-128-gcm"

    def self.generate_key
      SecureRandom.hex(OpenSSL::Cipher.new(CIPHER).key_len)
    end


    attr_reader :config_path, :key_path, :env_key

    def initialize(config_path:, key_path:, env_key:)
      @config_path, @key_path, @env_key = config_path, key_path, env_key
    end

    def data
      @data ||= YAML.load(read).deep_symbolize_keys
    end

    delegate :dig, :fetch, :[], to: :data


    def write(contents)
      IO.binwrite("#{config_path}.tmp", encrypt(contents))
      FileUtils.mv("#{config_path}.tmp", config_path)
    end

    def change(&block)
      writing(read, &block)
    end


    private
      def read
        if File.exist?(config_path)
          decrypt(IO.binread(config_path))
        else
          ""
        end
      end

      def writing(contents)
        tmp_file = "#{File.basename(config_path)}.#{Process.pid}"
        tmp_path = File.join(Dir.tmpdir, tmp_file)
        IO.binwrite(tmp_path, contents)

        yield tmp_path

        updated_contents = IO.binread(tmp_path)

        write(updated_contents) if updated_contents != contents
      ensure
        FileUtils.rm(tmp_path) if File.exist?(tmp_path)
      end


      def encrypt(contents)
        encryptor.encrypt_and_sign(contents)
      end

      def decrypt(contents)
        encryptor.decrypt_and_verify(contents)
      end

      def encryptor
        @encryptor ||= ActiveSupport::MessageEncryptor.new([ key ].pack("H*"), cipher: CIPHER)
      end


      def key
        read_env_key || read_key_file || handle_missing_key
      end

      def read_env_key
        ENV[env_key]
      end

      def read_key_file
        if File.exist?(key_path)
          IO.binread(key_path).strip
        end
      end

      def handle_missing_key
        raise MissingKeyError.new(key_path: key_path, env_key: env_key)
      end
  end
end
