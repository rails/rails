require 'time'
require 'switchtower/scm/base'

module SwitchTower
  module SCM

    # An SCM module for using CVS as your source control tool. You can
    # specify it by placing the following line in your configuration:
    #
    #   set :scm, :cvs
    #
    # Also, this module accepts a <tt>:cvs</tt> configuration variable,
    # which (if specified) will be used as the full path to the cvs
    # executable on the remote machine:
    #
    #   set :cvs, "/opt/local/bin/cvs"
    #
    # You can specify the location of your local copy (used to query
    # the revisions, etc.) via the <tt>:local</tt> variable, which defaults to
    # ".".
    #
    # Also, you can specify the CVS_RSH variable to use on the remote machine(s)
    # via the <tt>:cvs_rsh</tt> variable. This defaults to the value of the
    # CVS_RSH environment variable locally, or if it is not set, to "ssh".
    class Cvs < Base
      # Return a string representing the date of the last revision (CVS is
      # seriously retarded, in that it does not give you a way to query when
      # the last revision was made to the repository, so this is a fairly
      # expensive operation...)
      def latest_revision
        return @latest_revision if @latest_revision
        configuration.logger.debug "querying latest revision..."
        @latest_revision = cvs_log(configuration.local).
          split(/\r?\n/).
          grep(/^date: (.*?);/) { Time.parse($1).strftime("%F %T") }.
          sort.
          last
      end

      # Check out (on all servers associated with the current task) the latest
      # revision. Uses the given actor instance to execute the command.
      def checkout(actor)
        cvs = configuration[:cvs] || "cvs"
        cvs_rsh = configuration[:cvs_rsh] || ENV['CVS_RSH'] || "ssh"

        command = <<-CMD
          cd #{configuration.releases_path};
          CVS_RSH="#{cvs_rsh}" #{cvs} -d #{configuration.repository} -Q co -D "#{configuration.revision}" -d #{File.basename(actor.release_path)} #{actor.application};
        CMD

        run_checkout(actor, command) do |ch, stream, out|
          prefix = "#{stream} :: #{ch[:host]}"
          actor.logger.info out, prefix
          if out =~ %r{password:}
            actor.logger.info "CVS is asking for a password", prefix
            ch.send_data "#{actor.password}\n"
          elsif out =~ %r{^Enter passphrase}
            message = "CVS needs your key's passphrase and cannot proceed"
            actor.logger.info message, prefix
            raise message
          end
        end
      end

      private

        def cvs_log(path)
          `cd #{path || "."} && cvs -q log -N -rHEAD`
        end
    end

  end
end
