require 'fileutils'

Dir[File.join(File.dirname(__FILE__), "actions", "*.rb")].each do |action|
  require action
end

class Thor
  module Actions
    attr_accessor :behavior

    # On inclusion, add some options to base.
    #
    def self.included(base) #:nodoc:
      base.extend ClassMethods
      return unless base.respond_to?(:class_option)

      base.class_option :pretend, :type => :boolean, :aliases => "-p", :group => :runtime,
                                  :desc => "Run but do not make any changes"

      base.class_option :force, :type => :boolean, :aliases => "-f", :group => :runtime,
                                :desc => "Overwrite files that already exist"

      base.class_option :skip, :type => :boolean, :aliases => "-s", :group => :runtime,
                               :desc => "Skip files that already exist"

      base.class_option :quiet, :type => :boolean, :aliases => "-q", :group => :runtime,
                                :desc => "Supress status output"
    end

    module ClassMethods
      # Hold source paths for one Thor instance. source_paths_for_search is the
      # method responsible to gather source_paths from this current class,
      # inherited paths and the source root.
      #
      def source_paths
        @source_paths ||= []
      end

      # Returns the source paths in the following order:
      #
      #   1) This class source paths
      #   2) Source root
      #   3) Parents source paths
      #
      def source_paths_for_search
        paths = []
        paths += self.source_paths
        paths << self.source_root if self.respond_to?(:source_root)
        paths += from_superclass(:source_paths, [])
        paths
      end
    end

    # Extends initializer to add more configuration options.
    #
    # ==== Configuration
    # behavior<Symbol>:: The actions default behavior. Can be :invoke or :revoke.
    #                    It also accepts :force, :skip and :pretend to set the behavior
    #                    and the respective option.
    #
    # destination_root<String>:: The root directory needed for some actions.
    #
    def initialize(args=[], options={}, config={})
      self.behavior = case config[:behavior].to_s
        when "force", "skip"
          _cleanup_options_and_set(options, config[:behavior])
          :invoke
        when "revoke"
          :revoke
        else
          :invoke
      end

      super
      self.destination_root = config[:destination_root]
    end

    # Wraps an action object and call it accordingly to the thor class behavior.
    #
    def action(instance) #:nodoc:
      if behavior == :revoke
        instance.revoke!
      else
        instance.invoke!
      end
    end

    # Returns the root for this thor class (also aliased as destination root).
    #
    def destination_root
      @destination_stack.last
    end

    # Sets the root for this thor class. Relatives path are added to the
    # directory where the script was invoked and expanded.
    #
    def destination_root=(root)
      @destination_stack ||= []
      @destination_stack[0] = File.expand_path(root || '')
    end

    # Returns the given path relative to the absolute root (ie, root where
    # the script started).
    #
    def relative_to_original_destination_root(path, remove_dot=true)
      path = path.gsub(@destination_stack[0], '.')
      remove_dot ? (path[2..-1] || '') : path
    end

    # Holds source paths in instance so they can be manipulated.
    #
    def source_paths
      @source_paths ||= self.class.source_paths_for_search
    end

    # Receives a file or directory and search for it in the source paths. 
    #
    def find_in_source_paths(file)
      relative_root = relative_to_original_destination_root(destination_root, false)

      source_paths.each do |source|
        source_file = File.expand_path(file, File.join(source, relative_root))
        return source_file if File.exists?(source_file)
      end

      if source_paths.empty?
        raise Error, "You don't have any source path defined for class #{self.class.name}. To fix this, " <<
                     "you can define a source_root in your class."
      else
        raise Error, "Could not find #{file.inspect} in source paths."
      end
    end

    # Do something in the root or on a provided subfolder. If a relative path
    # is given it's referenced from the current root. The full path is yielded
    # to the block you provide. The path is set back to the previous path when
    # the method exits.
    #
    # ==== Parameters
    # dir<String>:: the directory to move to.
    # config<Hash>:: give :verbose => true to log and use padding.
    #
    def inside(dir='', config={}, &block)
      verbose = config.fetch(:verbose, false)

      say_status :inside, dir, verbose
      shell.padding += 1 if verbose
      @destination_stack.push File.expand_path(dir, destination_root)

      FileUtils.mkdir_p(destination_root) unless File.exist?(destination_root)
      FileUtils.cd(destination_root) { block.arity == 1 ? yield(destination_root) : yield }

      @destination_stack.pop
      shell.padding -= 1 if verbose
    end

    # Goes to the root and execute the given block.
    #
    def in_root
      inside(@destination_stack.first) { yield }
    end

    # Loads an external file and execute it in the instance binding.
    #
    # ==== Parameters
    # path<String>:: The path to the file to execute. Can be a web address or
    #                a relative path from the source root.
    #
    # ==== Examples
    #
    #   apply "http://gist.github.com/103208"
    #
    #   apply "recipes/jquery.rb"
    #
    def apply(path, config={})
      verbose = config.fetch(:verbose, true)
      path    = find_in_source_paths(path) unless path =~ /^http\:\/\//

      say_status :apply, path, verbose
      shell.padding += 1 if verbose
      instance_eval(open(path).read)
      shell.padding -= 1 if verbose
    end

    # Executes a command.
    #
    # ==== Parameters
    # command<String>:: the command to be executed.
    # config<Hash>:: give :verbose => false to not log the status. Specify :with
    #                to append an executable to command executation.
    #
    # ==== Example
    #
    #   inside('vendor') do
    #     run('ln -s ~/edge rails')
    #   end
    #
    def run(command, config={})
      return unless behavior == :invoke

      destination = relative_to_original_destination_root(destination_root, false)
      desc = "#{command} from #{destination.inspect}"

      if config[:with]
        desc = "#{File.basename(config[:with].to_s)} #{desc}"
        command = "#{config[:with]} #{command}"
      end

      say_status :run, desc, config.fetch(:verbose, true)
      system(command) unless options[:pretend]
    end

    # Executes a ruby script (taking into account WIN32 platform quirks).
    #
    # ==== Parameters
    # command<String>:: the command to be executed.
    # config<Hash>:: give :verbose => false to not log the status.
    #
    def run_ruby_script(command, config={})
      return unless behavior == :invoke
      run "#{command}", config.merge(:with => Thor::Util.ruby_command)
    end

    # Run a thor command. A hash of options can be given and it's converted to 
    # switches.
    #
    # ==== Parameters
    # task<String>:: the task to be invoked
    # args<Array>:: arguments to the task
    # config<Hash>:: give :verbose => false to not log the status. Other options
    #                are given as parameter to Thor.
    #
    # ==== Examples
    #
    #   thor :install, "http://gist.github.com/103208"
    #   #=> thor install http://gist.github.com/103208
    #
    #   thor :list, :all => true, :substring => 'rails'
    #   #=> thor list --all --substring=rails
    #
    def thor(task, *args)
      config  = args.last.is_a?(Hash) ? args.pop : {}
      verbose = config.key?(:verbose) ? config.delete(:verbose) : true

      args.unshift task
      args.push Thor::Options.to_switches(config)
      command = args.join(' ').strip

      run command, :with => :thor, :verbose => verbose
    end

    protected

      # Allow current root to be shared between invocations.
      #
      def _shared_configuration #:nodoc:
        super.merge!(:destination_root => self.destination_root)
      end

      def _cleanup_options_and_set(options, key) #:nodoc:
        case options
          when Array
            %w(--force -f --skip -s).each { |i| options.delete(i) }
            options << "--#{key}"
          when Hash
            [:force, :skip, "force", "skip"].each { |i| options.delete(i) }
            options.merge!(key => true)
        end
      end

  end
end
