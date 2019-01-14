# frozen_string_literal: true

module ActiveStorage
  class ServiceRegistry #:nodoc:
    class << self
      def fetch(service_name, &block)
        services.fetch(service_name.to_s, &block)
      end

      private
        def services
          @services ||= configs.keys.each_with_object({}) do |service_name, hash|
            hash[service_name] = ActiveStorage::Service.configure(service_name, configs)
          end
        end

        def configs
          Rails.configuration.active_storage.service_configurations ||= begin
            config_file = Pathname.new(Rails.root.join("config/storage.yml"))
            raise("Couldn't find Active Storage configuration in #{config_file}") unless config_file.exist?

            require "yaml"
            require "erb"

            YAML.load(ERB.new(config_file.read).result) || {}
          rescue Psych::SyntaxError => e
            raise "YAML syntax error occurred while parsing #{config_file}. " \
                  "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
                  "Error: #{e.message}"
          end
        end
    end
  end
end
