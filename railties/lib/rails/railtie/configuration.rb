require 'rails/configuration'

module Rails
  class Railtie
    class Configuration
      include Rails::Configuration::Shared
    end
  end
end