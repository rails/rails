# frozen_string_literal: true

module ActiveStorage
  class Service::Registry # :nodoc:
    def initialize(configurations)
      @configurations = configurations.deep_symbolize_keys
      @services = {}
    end

    def fetch(name)
      services.fetch(name.to_sym) do |key|
        if configurations.include?(key)
          services[key] = configurator.build(key)
        else
          if block_given?
            yield key
          else
            raise KeyError, "Missing configuration for the #{key} Active Storage service. " \
              "Configurations available for the #{configurations.keys.to_sentence} services."
          end
        end
      end
    end

    private
      attr_reader :configurations, :services

      def configurator
        @configurator ||= ActiveStorage::Service::Configurator.new(configurations)
      end
  end
end
