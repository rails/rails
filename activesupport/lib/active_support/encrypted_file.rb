# frozen_string_literal: true

require "pathname"
require "tmpdir"
require "active_support/message_encryptor"

module ActiveSupport
  class EncryptedFile
    class MissingContentError < RuntimeError
      def initialize(content_path)
        super "Missing encrypted content file in #{content_path}."
      end
    end

    class MissingKeyError < RuntimeError
      def initialize(key_path:, env_key:)
        super \
          "Missing encryption key to decrypt file with. " +
          "Ask your team for your master key and write it to #{key_path} or put it in the ENV['#{env_key}']."
      end
    end

    CIPHER = "aes-128-gcm"

    def self.generate_key
      SecureRandom.hex(ActiveSupport::MessageEncryptor.key_len(CIPHER))
    end


    attr_reader :content_path, :key_path, :env_key, :raise_if_missing_key

    def initialize(content_path:, key_path:, env_key:, raise_if_missing_key:)
      @content_path = Pathname.new(content_path).yield_self { |path| path.symlink? ? path.realpath : path }
      @key_path = Pathname.new(key_path)
      @env_key, @raise_if_missing_key = env_key, raise_if_missing_key
    end

    def key
      read_env_key || read_key_file || handle_missing_key
    end

    def read
      if !key.nil? && content_path.exist?
        decrypt content_path.binread
      else
        raise MissingContentError, content_path
      end
    end

    def write(contents)
      IO.binwrite "#{content_path}.tmp", encrypt(contents)
      FileUtils.mv "#{content_path}.tmp", content_path
    end

    def change(&block)
      writing read, &block
    end


    private
      def writing(contents)
        tmp_file = "#{Process.pid}.#{content_path.basename.to_s.chomp('.enc')}"
        tmp_path = Pathname.new File.join(Dir.tmpdir, tmp_file)
        tmp_path.binwrite contents

        yield tmp_path

        updated_contents = tmp_path.binread

        write(updated_contents) if updated_contents != contents
      ensure
        FileUtils.rm(tmp_path) if tmp_path&.exist?
      end


      def encrypt(contents)
        encryptor.encrypt_and_sign contents
      end

      def decrypt(contents)
        encryptor.decrypt_and_verify contents
      end

      def encryptor
        @encryptor ||= ActiveSupport::MessageEncryptor.new([ key ].pack("H*"), cipher: CIPHER)
      end


      def read_env_key
        ENV[env_key]
      end

      def read_key_file
        key_path.binread.strip if key_path.exist?
      end

      def handle_missing_key
        raise MissingKeyError.new(key_path: key_path, env_key: env_key) if raise_if_missing_key
      end
  end
end
