module Rails
  class Engine < Railtie
    class Railties
      include Enumerable
      attr_reader :_all

      def initialize
        @_all ||= ::Rails::Railtie.subclasses.map(&:instance) +
          ::Rails::Engine.subclasses.map(&:instance)
      end

      def self.engines
        @engines ||= ::Rails::Engine.subclasses.map(&:instance)
      end

      def each(*args, &block)
        _all.each(*args, &block)
      end

      def -(others)
        _all - others
      end

      delegate :engines, to: "self.class"
    end
  end
end

ActiveSupport::Deprecation.deprecate_methods(Rails::Engine::Railties, :engines)
