module SwitchTower
  module SCM

    # The ancestor class of the various SCM module implementations.
    class Base
      attr_reader :configuration

      def initialize(configuration) #:nodoc:
        @configuration = configuration
      end

      def checkout(actor)
        raise NotImplementedError, "subclasses must implement checkout"
      end
    end

  end
end
