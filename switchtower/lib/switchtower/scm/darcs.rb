require 'switchtower/scm/base'

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
    class Darcs < Base
      # Check out (on all servers associated with the current task) the latest
      # revision. Uses the given actor instance to execute the command.
      def checkout(actor)
        darcs = configuration[:darcs] ? configuration[:darcs] : "darcs"
        run_checkout(actor, "#{darcs} get -q --set-scripts-executable #{configuration.repository} #{actor.release_path};")
      end
    end

  end
end
