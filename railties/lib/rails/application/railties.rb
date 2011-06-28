require 'rails/engine/railties'

module Rails
  class Application < Engine
    class Railties < Rails::Engine::Railties
      def all(&block)
        @all ||= railties + engines + plugins
        @all.each(&block) if block
        @all
      end
    end
  end
end
