require "yaml"

module Rails
  # Greatly inspired by Ara T. Howard's magnificent sekrets gem. 😘
  class Secrets # :nodoc:
    class MissingKeyError < RuntimeError
      def initialize
        super("Missing key to decrypt secrets with. Put your key in the RAILS_MASTER_KEY environment variable or in a version control ignored config/secrets.yml.key file")
      end
    end

    class << self
      def parse(paths, env:)
        paths.each_with_object(Hash.new) do |path, all_secrets|
          require "erb"

          secrets = YAML.load(ERB.new(preprocess(path)).result) || {}
          all_secrets.merge!(secrets["shared"].deep_symbolize_keys) if secrets["shared"]
          all_secrets.merge!(secrets[env].deep_symbolize_keys) if secrets[env]
        end
      end

      def key
        ENV["RAILS_MASTER_KEY"] || read_key_file || raise(MissingKeyError)
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
        FileUtils.rm(tmp_path)
      end

      private
        def read_key_file
          if File.exist?(key_path)
            IO.binread(key_path).strip
          end
        end

        def path
          Rails.root.join("config", "secrets.yml.enc").to_s
        end

        def key_path
          Rails.root.join("config", "secrets.yml.key")
        end

        def preprocess(path)
          if path.end_with?(".enc")
            decrypt(IO.binread(path))
          else
            IO.read(path)
          end
        end

        def cipher(mode, data)
          cipher = OpenSSL::Cipher::Cipher.new("bf-cbc").public_send(mode)
          cipher.key = Digest::SHA256.digest(key.to_s)
          cipher.update(data) << cipher.final
        end
    end
  end
end
