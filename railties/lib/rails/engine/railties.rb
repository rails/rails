module Rails
  class Engine < Railtie
    class Railties
      # TODO Write tests for this behavior extracted from Application
      def initialize(config)
        @config = config
      end

      def all(&block)
        @all ||= []
        @all.each(&block) if block
        @all
      end

      def self.railties
        @railties ||= ::Rails::Railtie.subclasses.map(&:instance)
      end

      def self.engines
        @engines ||= ::Rails::Engine.subclasses.map(&:instance)
      end

      delegate :railties, :engines, :to => "self.class"
    end
  end
end
