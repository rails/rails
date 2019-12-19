# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/plugin/plugin_generator"

module Rails
  class Engine
    class Updater
      class << self
        def generator
          @generator ||= Rails::Generators::PluginGenerator.new ["plugin"],
            { engine: true }, { destination_root: ENGINE_ROOT }
        end

        def run(action)
          generator.send(action)
        end
      end
    end
  end
end
