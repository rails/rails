require 'rails/engine/railties'

module Rails
  class Application < Engine
    class Railties < Rails::Engine::Railties
      def all(&block)
        @railties_plus_engines ||= railties + engines
        @railties_plus_engines.each(&block) if block
        @railties_plus_engines + super
      end
    end
  end
end
