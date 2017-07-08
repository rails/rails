class ActiveStorage::Service::Configurator #:nodoc:
  def initialize(service_name, configurations)
    @service_name, @configurations = service_name.to_sym, configurations.symbolize_keys
  end

  def build
    service_class.build(service_config.except(:service), @configurations)
  end

  private
    def service_class
      resolve service_class_name
    end

    def service_class_name
      service_config.fetch :service do
        raise "Missing Active Storage `service: …` configuration for #{service_config.inspect}"
      end
    end

    def service_config
      @configurations.fetch @service_name do
        raise "Missing configuration for the #{@service_name.inspect} Active Storage service. Configurations available for #{@configurations.keys.inspect}"
      end
    end

    def resolve(service_class_name)
      require "active_storage/service/#{service_class_name.to_s.downcase}_service"
      ActiveStorage::Service.const_get(:"#{service_class_name}Service")
    end
end
