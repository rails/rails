require 'switchtower/scm/base'

module SwitchTower
  module SCM

    # An SCM module for using subversion as your source control tool. This
    # module is used by default, but you can explicitly specify it by
    # placing the following line in your configuration:
    #
    #   set :scm, :subversion
    #
    # Also, this module accepts a <tt>:svn</tt> configuration variable,
    # which (if specified) will be used as the full path to the svn
    # executable on the remote machine:
    #
    #   set :svn, "/opt/local/bin/svn"
    class Subversion < Base
      # Return an integer identifying the last known revision in the svn
      # repository. (This integer is currently the revision number.) If latest
      # revision does not exist in the given repository, this routine will
      # walk up the directory tree until it finds it.
      def latest_revision
        configuration.logger.debug "querying latest revision..." unless @latest_revision
        repo = configuration.repository
        until @latest_revision
          match = svn_log(repo).scan(/r(\d+)/).first
          @latest_revision = match ? match.first : nil
          if @latest_revision.nil?
            # if a revision number was not reported, move up a level in the path
            # and try again.
            repo = File.dirname(repo)
          end
        end
        @latest_revision
      end

      # Check out (on all servers associated with the current task) the latest
      # revision. Uses the given actor instance to execute the command. If
      # svn asks for a password this will automatically provide it (assuming
      # the requested password is the same as the password for logging into the
      # remote server.)
      def checkout(actor)
        svn = configuration[:svn] ? configuration[:svn] : "svn"

        command = <<-CMD
          if [[ -d #{actor.release_path} ]]; then
            #{svn} up -q -r#{latest_revision} #{actor.release_path};
          else
            #{svn} co -q -r#{latest_revision} #{configuration.repository} #{actor.release_path};
          fi
        CMD
        actor.run(command) do |ch, stream, out|
          prefix = "#{stream} :: #{ch[:host]}"
          actor.logger.info out, prefix
          if out =~ /^Password.*:/
            actor.logger.info "subversion is asking for a password", prefix
            ch.send_data "#{actor.password}\n"
          elsif out =~ %r{\(yes/no\)}
            actor.logger.info "subversion is asking whether to connect or not",
              prefix
            ch.send_data "yes\n"
          elsif out =~ %r{passphrase}
            message = "subversion needs your key's passphrase, sending empty string"
            actor.logger.info message, prefix
            ch.send_data "\n"
          elsif out =~ %r{The entry \'(\w+)\' is no longer a directory}
            message = "subversion can't update because directory '#{$1}' was replaced. Please add it to svn:ignore."
            actor.logger.info message, prefix
            raise message
          end
        end
      end

      private
      
        def svn_log(path)
          `svn log -q -rhead #{path}`
        end
    end

  end
end
