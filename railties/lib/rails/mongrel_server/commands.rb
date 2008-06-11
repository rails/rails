# Copyright (c) 2005 Zed A. Shaw
# You can redistribute it and/or modify it under the same terms as Ruby.
#
# Additional work donated by contributors.  See http://mongrel.rubyforge.org/attributions.html
# for more information.

require 'optparse'
require 'yaml'
require 'etc'

require 'mongrel'
require 'rails/mongrel_server/handler'

module Rails
  module MongrelServer
    def self.send_signal(signal, pid_file)
      pid = open(pid_file).read.to_i
      print "Sending #{signal} to Mongrel at PID #{pid}..."
      begin
        Process.kill(signal, pid)
      rescue Errno::ESRCH
        puts "Process does not exist.  Not running."
      end

      puts "Done."
    end

    class RailsConfigurator < Mongrel::Configurator
      def setup_mime_types
        mime = {}

        if defaults[:mime_map]
          Mongrel.log("Loading additional MIME types from #{defaults[:mime_map]}")
          mime = load_mime_map(defaults[:mime_map], mime)
        end

        mime.each {|k,v| Mongrel::DirHandler::add_mime_type(k,v) }
      end

      def mount_rails(prefix)
        ENV['RAILS_ENV'] = defaults[:environment]
        ::RAILS_ENV.replace(defaults[:environment]) if defined?(::RAILS_ENV)

        env_location = "#{defaults[:cwd]}/config/environment"
        require env_location

        ActionController::AbstractRequest.relative_url_root = defaults[:prefix]
        uri prefix, :handler => Rails::MongrelServer::RailsHandler.new
      end
    end

    class Start < GemPlugin::Plugin "/commands"
      include Mongrel::Command::Base

      def configure
        options [
          ["-e", "--environment ENV", "Rails environment to run as", :@environment, ENV['RAILS_ENV'] || "development"],
          ["-d", "--daemonize", "Run daemonized in the background", :@daemon, false],
          ['-p', '--port PORT', "Which port to bind to", :@port, 3000],
          ['-a', '--address ADDR', "Address to bind to", :@address, "0.0.0.0"],
          ['-l', '--log FILE', "Where to write log messages", :@log_file, "log/mongrel.log"],
          ['-P', '--pid FILE', "Where to write the PID", :@pid_file, "tmp/pids/mongrel.pid"],
          ['-n', '--num-procs INT', "Number of processors active before clients denied", :@num_procs, 1024],
          ['-o', '--timeout TIME', "Time to wait (in seconds) before killing a stalled thread", :@timeout, 60],
          ['-t', '--throttle TIME', "Time to pause (in hundredths of a second) between accepting clients", :@throttle, 0],
          ['-m', '--mime PATH', "A YAML file that lists additional MIME types", :@mime_map, nil],
          ['-c', '--chdir PATH', "Change to dir before starting (will be expanded)", :@cwd, RAILS_ROOT],
          ['-r', '--root PATH', "Set the document root (default 'public')", :@docroot, "public"],
          ['-B', '--debug', "Enable debugging mode", :@debug, false],
          ['-C', '--config PATH', "Use a config file", :@config_file, nil],
          ['-S', '--script PATH', "Load the given file as an extra config script", :@config_script, nil],
          ['-G', '--generate PATH', "Generate a config file for use with -C", :@generate, nil],
          ['', '--user USER', "User to run as", :@user, nil],
          ['', '--group GROUP', "Group to run as", :@group, nil],
          ['', '--prefix PATH', "URL prefix for Rails app", :@prefix, nil],

          ['-b', '--binding ADDR', "Address to bind to (deprecated, use -a)", :@address, "0.0.0.0"],
          ['-u', '--debugger', "Enable debugging mode (deprecated, use -B)", :@debug, false]
        ]
      end

      def validate
        if @config_file
          valid_exists?(@config_file, "Config file not there: #@config_file")
          return false unless @valid
          @config_file = File.expand_path(@config_file)
          load_config
          return false unless @valid
        end

        @cwd = File.expand_path(@cwd)
        valid_dir? @cwd, "Invalid path to change to during daemon mode: #@cwd"

        # Change there to start, then we'll have to come back after daemonize
        Dir.chdir(@cwd)

        valid?(@prefix[0] == ?/ && @prefix[-1] != ?/, "Prefix must begin with / and not end in /") if @prefix
        valid_dir? File.dirname(@log_file), "Path to log file not valid: #@log_file"
        valid_dir? File.dirname(@pid_file), "Path to pid file not valid: #@pid_file"
        valid_dir? @docroot, "Path to docroot not valid: #@docroot"
        valid_exists? @mime_map, "MIME mapping file does not exist: #@mime_map" if @mime_map
        valid_exists? @config_file, "Config file not there: #@config_file" if @config_file
        valid_dir? File.dirname(@generate), "Problem accessing directory to #@generate" if @generate
        valid_user? @user if @user
        valid_group? @group if @group

        return @valid
      end

      def run
        if @generate
          @generate = File.expand_path(@generate)
          Mongrel.log(:error, "** Writing config to \"#@generate\".")
          open(@generate, "w") {|f| f.write(settings.to_yaml) }
          Mongrel.log(:error, "** Finished.  Run \"mongrel_rails start -C #@generate\" to use the config file.")
          exit 0
        end

        config = RailsConfigurator.new(settings) do
          defaults[:log] = $stdout if defaults[:environment] == 'development'

          Mongrel.log("=> Rails #{Rails.version} application starting on http://#{defaults[:host]}:#{defaults[:port]}")

          unless defaults[:daemon]
            Mongrel.log("=> Call with -d to detach")
            Mongrel.log("=> Ctrl-C to shutdown server")
            start_debugger if defaults[:debug]
          end

          if defaults[:daemon]
            if File.exist? defaults[:pid_file]
              Mongrel.log(:error, "!!! PID file #{defaults[:pid_file]} already exists.  Mongrel could be running already.  Check your #{defaults[:log_file]} for errors.")
              Mongrel.log(:error, "!!! Exiting with error.  You must stop mongrel and clear the .pid before I'll attempt a start.")
              exit 1
            end

            daemonize

            Mongrel.log("Daemonized, any open files are closed.  Look at #{defaults[:pid_file]} and #{defaults[:log_file]} for info.")
            Mongrel.log("Settings loaded from #{@config_file} (they override command line).") if @config_file
          end

          Mongrel.log("Starting Mongrel listening at #{defaults[:host]}:#{defaults[:port]}, further information can be found in log/mongrel-#{defaults[:host]}-#{defaults[:port]}.log")

          listener do
            prefix = defaults[:prefix] || '/'

            if defaults[:debug]
              Mongrel.log("Installing debugging prefixed filters. Look in log/mongrel_debug for the files.")
              debug(prefix)
            end

            setup_mime_types
            dir_handler = Mongrel::DirHandler.new(defaults[:docroot], false)
            dir_handler.passthrough_missing_files = true

            unless defaults[:environment] == 'production'
              Mongrel.log("Mounting DirHandler at #{prefix}...")
              uri prefix, :handler => dir_handler
            end


            Mongrel.log("Starting Rails with #{defaults[:environment]} environment...")
            Mongrel.log("Mounting Rails at #{prefix}...")
            mount_rails(prefix)
            Mongrel.log("Rails loaded.")


            Mongrel.log("Loading any Rails specific GemPlugins" )
            load_plugins

            if defaults[:config_script]
              Mongrel.log("Loading #{defaults[:config_script]} external config script")
              run_config(defaults[:config_script])
            end

            setup_signals
          end
        end

        config.run
        Mongrel.log("Mongrel #{Mongrel::Const::MONGREL_VERSION} available at #{@address}:#{@port}")

        if config.defaults[:daemon]
          config.write_pid_file
        else
          Mongrel.log("Use CTRL-C to stop.")
          tail "log/#{config.defaults[:environment]}.log"
        end

        config.join

        if config.needs_restart
          unless RUBY_PLATFORM =~ /djgpp|(cyg|ms|bcc)win|mingw/
            cmd = "ruby #{__FILE__} start #{original_args.join(' ')}"
            Mongrel.log("Restarting with arguments:  #{cmd}")
            config.stop(false, true)
            config.remove_pid_file

            if config.defaults[:daemon]
              system cmd
            else
              Mongrel.log(:error, "Can't restart unless in daemon mode.")
              exit 1
            end
          else
            Mongrel.log("Win32 does not support restarts. Exiting.")
          end
        end
      end

      def load_config
        settings = {}
        begin
          settings = YAML.load_file(@config_file)
        ensure
          Mongrel.log(:error, "** Loading settings from #{@config_file} (they override command line).") unless @daemon || settings[:daemon]
        end

        settings[:includes] ||= ["mongrel"]

        # Config file settings will override command line settings
        settings.each do |key, value|
          key = key.to_s
          if config_keys.include?(key)
            key = 'address' if key == 'host'
            self.instance_variable_set("@#{key}", value)
          else
            failure "Unknown configuration setting: #{key}"
            @valid = false
          end
        end
      end

      def config_keys
        @config_keys ||=
          %w(address host port cwd log_file pid_file environment docroot mime_map daemon debug includes config_script num_processors timeout throttle user group prefix)
      end

      def settings
        config_keys.inject({}) do |hash, key|
          value = self.instance_variable_get("@#{key}")
          key = 'host' if key == 'address'
          hash[key.to_sym] ||= value
          hash
        end
      end

      def start_debugger
        require_library_or_gem 'ruby-debug'
        Debugger.start
        Debugger.settings[:autoeval] = true if Debugger.respond_to?(:settings)
        Mongrel.log("=> Debugger enabled")
      rescue Exception
        Mongrel.log(:error, "You need to install ruby-debug to run the server in debugging mode. With gems, use 'gem install ruby-debug'")
        exit
      end

      def tail(log_file)
        cursor = File.size(log_file)
        last_checked = Time.now
        tail_thread = Thread.new do
          File.open(log_file, 'r') do |f|
            loop do
              f.seek cursor
              if f.mtime > last_checked
                last_checked = f.mtime
                contents = f.read
                cursor += contents.length
                print contents
              end
              sleep 1
            end
          end
        end
        tail_thread
      end
    end

    class Stop < GemPlugin::Plugin "/commands"
      include Mongrel::Command::Base

      def configure
        options [
          ['-c', '--chdir PATH', "Change to dir before starting (will be expanded).", :@cwd, "."],
          ['-f', '--force', "Force the shutdown (kill -9).", :@force, false],
          ['-w', '--wait SECONDS', "Wait SECONDS before forcing shutdown", :@wait, "0"],
          ['-P', '--pid FILE', "Where the PID file is located.", :@pid_file, "log/mongrel.pid"]
        ]
      end

      def validate
        @cwd = File.expand_path(@cwd)
        valid_dir? @cwd, "Invalid path to change to during daemon mode: #@cwd"

        Dir.chdir @cwd

        valid_exists? @pid_file, "PID file #@pid_file does not exist.  Not running?"
        return @valid
      end

      def run
        if @force
          @wait.to_i.times do |waiting|
            exit(0) if not File.exist? @pid_file
            sleep 1
          end

          Mongrel::send_signal("KILL", @pid_file) if File.exist? @pid_file
        else
          Mongrel::send_signal("TERM", @pid_file)
        end
      end
    end


    class Restart < GemPlugin::Plugin "/commands"
      include Mongrel::Command::Base

      def configure
        options [
          ['-c', '--chdir PATH', "Change to dir before starting (will be expanded)", :@cwd, '.'],
          ['-P', '--pid FILE', "Where the PID file is located", :@pid_file, "log/mongrel.pid"]
        ]
      end

      def validate
        @cwd = File.expand_path(@cwd)
        valid_dir? @cwd, "Invalid path to change to during daemon mode: #@cwd"

        Dir.chdir @cwd

        valid_exists? @pid_file, "PID file #@pid_file does not exist.  Not running?"
        return @valid
      end

      def run
        MongrelServer::send_signal("USR2", @pid_file)
      end
    end
  end
end
