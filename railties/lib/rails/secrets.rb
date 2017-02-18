require "yaml"
require "rails/engine" # Remove once sekrets dependency is gone.
require "sekrets"

module Rails
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
        Sekrets.encrypt(key, text)
      end

      def decrypt(data)
        Sekrets.decrypt(key, data)
      end

      def read
        Sekrets.read(path, key)
      end

      def write(contents)
        Sekrets.write(path, contents, key)
      end

      def read_for_editing
        Sekrets.tmpdir do
          tmp_path = File.basename(path)
          IO.binwrite(tmp_path, Secrets.read)

          yield tmp_path

          Secrets.write(IO.binread(tmp_path))
        end
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
    end
  end
end
