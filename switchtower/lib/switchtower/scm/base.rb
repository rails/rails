module SwitchTower
  module SCM

    # The ancestor class of the various SCM module implementations.
    class Base
      attr_reader :configuration

      def initialize(configuration) #:nodoc:
        @configuration = configuration
      end

      def latest_revision
        nil
      end

      private

        def run_checkout(actor, guts, &block)
          log = "#{configuration.deploy_to}/revisions.log"
          directory = File.basename(configuration.release_path)

          command = <<-STR
            if [[ ! -d #{configuration.release_path} ]]; then
              #{guts}
              echo `date +"%Y-%m-%d %H:%M:%S"` $USER #{latest_revision} #{directory} >> #{log};
              chmod 666 #{log};
            fi
          STR

          actor.run(command, &block)
        end
    end

  end
end
