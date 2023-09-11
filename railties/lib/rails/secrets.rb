# frozen_string_literal: true

require "yaml"
require "tempfile"
require "active_support/message_encryptor"

module Rails
  # Greatly inspired by Ara T. Howard's magnificent sekrets gem. 😘
  class Secrets # :nodoc:
    class MissingKeyError < RuntimeError
      def initialize
        super(<<-end_of_message.squish)
          Missing encryption key to decrypt secrets with.
          Ask your team for your master key and put it in ENV["RAILS_MASTER_KEY"]
        end_of_message
      end
    end

    @cipher = "aes-128-gcm"
    @root = File # Wonky, but ensures `join` uses the current directory.

    class << self
      attr_writer :root

      def parse(paths, env:)
        paths.each_with_object(Hash.new) do |path, all_secrets|
          require "erb"

          source = ERB.new(preprocess(path)).result
          secrets = YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(source) : YAML.load(source)
          secrets ||= {}

          all_secrets.merge!(secrets["shared"].deep_symbolize_keys) if secrets["shared"]
          all_secrets.merge!(secrets[env].deep_symbolize_keys) if secrets[env]
        end
      end

      def key
        ENV["RAILS_MASTER_KEY"] || read_key_file || handle_missing_key
      end

      def encrypt(data)
        encryptor.encrypt_and_sign(data)
      end

      def decrypt(data)
        encryptor.decrypt_and_verify(data)
      end

      def read
        decrypt(IO.binread(path))
      end

      def write(contents)
        IO.binwrite("#{path}.tmp", encrypt(contents))
        FileUtils.mv("#{path}.tmp", path)
      end

      def read_for_editing(&block)
        writing(read, &block)
      end

      private
        def handle_missing_key
          raise MissingKeyError
        end

        def read_key_file
          if File.exist?(key_path)
            IO.binread(key_path).strip
          end
        end

        def key_path
          @root.join("config", "secrets.yml.key")
        end

        def path
          @root.join("config", "secrets.yml.enc").to_s
        end

        def preprocess(path)
          if path.end_with?(".enc")
            decrypt(IO.binread(path))
          else
            IO.read(path)
          end
        end

        def writing(contents)
          file_name = "#{File.basename(path)}.#{Process.pid}"

          Tempfile.create(["", "-" + file_name]) do |tmp_file|
            tmp_path = Pathname.new(tmp_file)
            tmp_path.binwrite contents

            yield tmp_path

            updated_contents = tmp_path.binread

            write(updated_contents) if updated_contents != contents
          end
        end

        def encryptor
          @encryptor ||= ActiveSupport::MessageEncryptor.new([ key ].pack("H*"), cipher: @cipher)
        end
    end
  end
end
