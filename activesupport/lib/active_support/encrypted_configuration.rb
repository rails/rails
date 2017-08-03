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

    attr_reader :config_path, :key_path, :env_key, :template

    delegate :dig, :[], to: :data

    def initialize(config_path:, key_path:, env_key:, template: nil)
      @config_path, @key_path, @env_path = config_path, key_path, env_key
      @template = template
    end

    def data
      @data ||= read
    end

    def generate_key
      SecureRandom.hex(OpenSSL::Cipher.new(CIPHER).key_len)
    end

    def key
      read_env_key || read_key_file || handle_missing_key
    end

    def encrypt(data)
      encryptor.encrypt_and_sign(data)
    end

    def decrypt(data)
      encryptor.decrypt_and_verify(data)
    end

    def read
      decrypt(IO.binread(configuration_path))
    end

    def write(contents)
      IO.binwrite("#{configuration_path}.tmp", encrypt(contents))
      FileUtils.mv("#{configuration_path}.tmp", configuration_path)
    end

    def read_for_editing(&block)
      writing(read, &block)
    end

    def read_template_for_editing(&block)
      writing(template, &block)
    end

    private
      def handle_missing_key
        raise MissingKeyError.new(key_path: key_path, env_key: env_key)
      end

      def read_key_file
        if File.exist?(key_path)
          IO.binread(key_path).strip
        end
      end

      def writing(contents)
        tmp_file = "#{File.basename(configuration_path)}.#{Process.pid}"
        tmp_path = File.join(Dir.tmpdir, tmp_file)
        IO.binwrite(tmp_path, contents)

        yield tmp_path

        updated_contents = IO.binread(tmp_path)

        write(updated_contents) if updated_contents != contents
      ensure
        FileUtils.rm(tmp_path) if File.exist?(tmp_path)
      end

      def encryptor
        @encryptor ||= ActiveSupport::MessageEncryptor.new([ key ].pack("H*"), cipher: CIPHER)
      end
  end
end
