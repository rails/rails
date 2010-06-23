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
        @railties ||= ::Rails::Railtie.subclasses.map(&:new)
      end

      def engines
        @engines ||= ::Rails::Engine.subclasses.map(&:instance)
      end

      def plugins
        @plugins ||= super + plugins_for_engines
      end

      def plugins_for_engines
        engines.map { |e|
          e.railties.plugins
        }.flatten
      end
    end
  end
end
