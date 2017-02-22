require "yaml"

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

    @read_encrypted_secrets = false
    @root = File # Wonky, but ensures `join` uses the current directory.

    class << self
      attr_writer   :root
      attr_accessor :read_encrypted_secrets

      def parse(paths, env:)
        paths.each_with_object(Hash.new) do |path, all_secrets|
          require "erb"

          secrets = YAML.load(ERB.new(preprocess(path)).result) || {}
          all_secrets.merge!(secrets["shared"].deep_symbolize_keys) if secrets["shared"]
          all_secrets.merge!(secrets[env].deep_symbolize_keys) if secrets[env]
        end
      end

      def generate_key
        cipher = new_cipher
        SecureRandom.hex(cipher.key_len)[0, cipher.key_len]
      end

      def key
        ENV["RAILS_MASTER_KEY"] || read_key_file || handle_missing_key
      end

      def encrypt(text)
        cipher(:encrypt, text)
      end

      def decrypt(data)
        cipher(:decrypt, data)
      end

      def read
        decrypt(IO.binread(path))
      end

      def write(contents)
        IO.binwrite("#{path}.tmp", encrypt(contents))
        FileUtils.mv("#{path}.tmp", path)
      end

      def read_for_editing
        tmp_path = File.join(Dir.tmpdir, File.basename(path))
        IO.binwrite(tmp_path, read)

        yield tmp_path

        write(IO.binread(tmp_path))
      ensure
        FileUtils.rm(tmp_path) if File.exist?(tmp_path)
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
            if @read_encrypted_secrets
              decrypt(IO.binread(path))
            else
              ""
            end
          else
            IO.read(path)
          end
        end

        def new_cipher
          OpenSSL::Cipher.new("aes-256-cbc")
        end

        def cipher(mode, data)
          cipher = new_cipher.public_send(mode)
          cipher.key = key
          cipher.update(data) << cipher.final
        end
    end
  end
end
