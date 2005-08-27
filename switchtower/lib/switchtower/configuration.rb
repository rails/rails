require 'switchtower/actor'
require 'switchtower/logger'
require 'switchtower/scm/subversion'

module SwitchTower

  # Represents a specific SwitchTower configuration. A Configuration instance
  # may be used to load multiple recipe files, define and describe tasks,
  # define roles, create an actor, and set configuration variables.
  class Configuration
    Role = Struct.new(:host, :options)

    DEFAULT_VERSION_DIR_NAME = "releases" #:nodoc:
    DEFAULT_CURRENT_DIR_NAME = "current"  #:nodoc:
    DEFAULT_SHARED_DIR_NAME  = "shared"   #:nodoc:

    # The actor created for this configuration instance.
    attr_reader :actor

    # The list of Role instances defined for this configuration.
    attr_reader :roles

    # The logger instance defined for this configuration.
    attr_reader :logger

    # The load paths used for locating recipe files.
    attr_reader :load_paths

    # The time (in UTC) at which this configuration was created, used for
    # determining the release path.
    attr_reader :now

    def initialize(actor_class=Actor) #:nodoc:
      @roles = Hash.new { |h,k| h[k] = [] }
      @actor = actor_class.new(self)
      @logger = Logger.new
      @load_paths = [".", File.join(File.dirname(__FILE__), "recipes")]
      @variables = {}
      @now = Time.now.utc

      set :application, nil
      set :repository,  nil
      set :gateway,     nil
      set :user,        nil
      set :password,    nil

      set :deploy_to,   Proc.new { "/u/apps/#{application}" }

      set :version_dir, DEFAULT_VERSION_DIR_NAME
      set :current_dir, DEFAULT_CURRENT_DIR_NAME
      set :shared_dir,  DEFAULT_SHARED_DIR_NAME
      set :scm,         :subversion

      set :revision,    Proc.new { source.latest_revision }
    end

    # Set a variable to the given value.
    def set(variable, value)
      @variables[variable] = value
    end

    alias :[]= :set

    # Access a named variable. If the value of the variable is a Proc instance,
    # the proc will be invoked and the return value cached and returned.
    def [](variable)
      set variable, @variables[variable].call if Proc === @variables[variable]
      @variables[variable]
    end

    # Based on the current value of the <tt>:scm</tt> variable, instantiate and
    # return an SCM module representing the desired source control behavior.
    def source
      @source ||= case scm
        when Class then
          scm.new(self)
        when String, Symbol then
          require "switchtower/scm/#{scm.to_s.downcase}"
          SwitchTower::SCM.const_get(scm.to_s.downcase.capitalize).new(self)
        else
          raise "invalid scm specification: #{scm.inspect}"
      end
    end

    # Load a configuration file or string into this configuration.
    #
    # Usage:
    #
    #   load("recipe"):
    #     Look for and load the contents of 'recipe.rb' into this
    #     configuration.
    #
    #   load(:file => "recipe"):
    #     same as above
    #
    #   load(:string => "set :scm, :subversion"):
    #     Load the given string as a configuration specification.
    def load(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      args.each { |arg| load options.merge(:file => arg) }

      if options[:file]
        file = options[:file]
        unless file[0] == ?/
          load_paths.each do |path|
            if File.file?(File.join(path, file))
              file = File.join(path, file)
              break
            elsif File.file?(File.join(path, file) + ".rb")
              file = File.join(path, file + ".rb")
              break
            end
          end
        end

        load :string => File.read(file), :name => options[:name] || file
      elsif options[:string]
        logger.debug "loading configuration #{options[:name] || "<eval>"}"
        instance_eval options[:string], options[:name] || "<eval>"
      end
    end

    # Define a new role and its associated servers. You must specify at least
    # one host for each role. Also, you can specify additional information
    # (in the form of a Hash) which can be used to more uniquely specify the
    # subset of servers specified by this specific role definition.
    #
    # Usage:
    #
    #   role :db, "db1.example.com", "db2.example.com"
    #   role :db, "master.example.com", :primary => true
    #   role :app, "app1.example.com", "app2.example.com"
    def role(which, *args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      raise ArgumentError, "must give at least one host" if args.empty?
      args.each { |host| roles[which] << Role.new(host, options) }
    end

    # Describe the next task to be defined. The given text will be attached to
    # the next task that is defined and used as its description.
    def desc(text)
      @next_description = text
    end

    # Define a new task. If a description is active (see #desc), it is added to
    # the options under the <tt>:desc</tt> key. This method ultimately
    # delegates to Actor#define_task.
    def task(name, options={}, &block)
      raise ArgumentError, "expected a block" unless block

      if @next_description
        options = options.merge(:desc => @next_description)
        @next_description = nil
      end

      actor.define_task(name, options, &block)
    end

    # Return the path into which releases should be deployed.
    def releases_path
      File.join(deploy_to, version_dir)
    end

    # Return the path identifying the +current+ symlink, used to identify the
    # current release.
    def current_path
      File.join(deploy_to, current_dir)
    end
    
    # Return the path into which shared files should be stored.
    def shared_path
      File.join(deploy_to, shared_dir)
    end

    # Return the full path to the named release. If a release is not specified,
    # +now+ is used (the time at which the configuration was created).
    def release_path(release=now.strftime("%Y%m%d%H%M%S"))
      File.join(releases_path, release)
    end

    def respond_to?(sym) #:nodoc:
      @variables.has_key?(sym) || super
    end

    def method_missing(sym, *args, &block) #:nodoc:
      if args.length == 0 && block.nil? && @variables.has_key?(sym)
        self[sym]
      else
        super
      end
    end
  end
end
