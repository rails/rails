require 'rails/engine/railties'

module Rails
  class Application < Engine
    class Railties < Rails::Engine::Railties
      def all(&block)
        @all ||= railties + engines + super
        @all.each(&block) if block
        @all
      end

      def railties
        @railties ||= ::Rails::Railtie.subclasses.map(&:instance)
      end

      def engines
        @engines ||= ::Rails::Engine.subclasses.map(&:instance)
      end
    end
  end
end
