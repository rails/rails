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

      def write(contents)
        Sekrets.write("config/secrets.yml.enc", contents, key)
      end

      private
        def read_key_file
          if File.exist?("config/secrets.yml.key")
            IO.binread("config/secrets.yml.key").strip
          end
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
