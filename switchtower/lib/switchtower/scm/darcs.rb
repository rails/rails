require 'time'

module SwitchTower
  module SCM

    # An SCM module for using darcs as your source control tool. Use it by
    # specifying the following line in your configuration:
    #
    #   set :scm, :darcs
    #
    # Also, this module accepts a <tt>:darcs</tt> configuration variable,
    # which (if specified) will be used as the full path to the darcs
    # executable on the remote machine:
    #
    #   set :darcs, "/opt/local/bin/darcs"
    class Darcs
      attr_reader :configuration

      def initialize(configuration) #:nodoc:
        @configuration = configuration
      end

      # Return an integer identifying the last known revision (patch) in the
      # darcs repository. (This integer is currently the 14-digit timestamp
      # of the last known patch.)
      def latest_revision
        unless @latest_revision
          configuration.logger.debug "querying latest revision..."
          @latest_revision = Time.
            parse(`darcs changes --last 1 --repo #{configuration.repository}`).
            strftime("%Y%m%d%H%M%S").to_i
        end
        @latest_revision
      end

      # Check out (on all servers associated with the current task) the latest
      # revision. Uses the given actor instance to execute the command.
      def checkout(actor)
        darcs = configuration[:darcs] ? configuration[:darcs] : "darcs"

        command = <<-CMD
          if [[ ! -d #{actor.release_path} ]]; then
            #{darcs} get --set-scripts-executable #{configuration.repository} #{actor.release_path};
          fi
        CMD
        actor.run(command)
      end
    end

  end
end
