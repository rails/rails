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
      # Hold source paths used by Thor::Actions.
      #
      def source_paths
        @source_paths ||= from_superclass(:source_paths, [])
      end

      # On inheritance, add source root to source paths so dynamic source_root
      # (that depends on the class name, for example) are cached properly.
      #
      def inherited(base) #:nodoc:
        super
        base.source_paths
        if base.respond_to?(:source_root) && !base.source_paths.include?(base.source_root)
          base.source_paths.unshift(base.source_root)
        end
      end

      # Deal with source root cache in source_paths. source_paths in the
      # inheritance chain are tricky to implement because:
      #
      # 1) We have to ensure that paths from the parent class appears later in
      #    the source paths array.
      #
      # 2) Whenever source_root is added, it has to be cached because __FILE__
      #    in ruby returns relative locations.
      #
      # 3) If someone wants to add source paths dinamically, added paths have
      #    to come before the source root.
      #
      # This method basically check if source root was added and put it between
      # the inherited paths and the user added paths.
      #
      def singleton_method_added(method) #:nodoc:
        if method == :source_root
          inherited_paths = from_superclass(:source_paths, [])

          self.source_paths.reject!{ |path| inherited_paths.include?(path) }
          self.source_paths.push(*self.source_root)
          self.source_paths.concat(inherited_paths)
        end
      end
    end

    # Extends initializer to add more configuration options.
    #
    # ==== Configuration
    # behavior<Symbol>:: The actions default behavior. Can be :invoke or :revoke.
    #                    It also accepts :force, :skip and :pretend to set the behavior
    #                    and the respective option.
    #
    # destination_root<String>:: The root directory needed for some actions. It's also known
    #                            as destination root.
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
    def action(instance)
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

    # Receives a file or directory and search for it in the source paths. 
    #
    def find_in_source_paths(file)
      relative_root = relative_to_original_destination_root(destination_root, false)
      source_file   = nil

      self.class.source_paths.each do |source|
        source_file = File.expand_path(file, File.join(source, relative_root))
        return source_file if File.exists?(source_file)
      end

      if self.class.source_paths.empty?
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
    #
    def inside(dir='', &block)
      @destination_stack.push File.expand_path(dir, destination_root)
      FileUtils.mkdir_p(destination_root) unless File.exist?(destination_root)
      FileUtils.cd(destination_root) { block.arity == 1 ? yield(destination_root) : yield }
      @destination_stack.pop
    end

    # Same as inside, but log status and use padding.
    #
    def inside_with_padding(dir='', log_status=true, &block)
      say_status :inside, dir, log_status
      shell.padding += 1
      inside(dir, &block)
      shell.padding -= 1
    end

    # Goes to the root and execute the given block.
    #
    def in_root
      inside(@destination_stack.first) { yield }
    end

    # Changes the mode of the given file or directory.
    #
    # ==== Parameters
    # mode<Integer>:: the file mode
    # path<String>:: the name of the file to change mode
    # log_status<Boolean>:: if false, does not log the status. True by default.
    #                       If a symbol is given, uses it as the output color.
    #
    # ==== Example
    #
    #   chmod "script/*", 0755
    #
    def chmod(path, mode, log_status=true)
      return unless behavior == :invoke
      path = File.expand_path(path, destination_root)
      say_status :chmod, relative_to_original_destination_root(path), log_status
      FileUtils.chmod_R(mode, path) unless options[:pretend]
    end

    # Executes a command.
    #
    # ==== Parameters
    # command<String>:: the command to be executed.
    # log_status<Boolean>:: if false, does not log the status. True by default.
    #                       If a symbol is given, uses it as the output color.
    #
    # ==== Example
    #
    #   inside('vendor') do
    #     run('ln -s ~/edge rails')
    #   end
    #
    def run(command, log_status=true)
      return unless behavior == :invoke
      say_status :run, "\"#{command}\" from #{relative_to_original_destination_root(destination_root, false)}", log_status
      `#{command}` unless options[:pretend]
    end

    # Executes a ruby script (taking into account WIN32 platform quirks).
    #
    # ==== Parameters
    # command<String>:: the command to be executed.
    # log_status<Boolean>:: if false, does not log the status. True by default.
    #                       If a symbol is given, uses it as the output color.
    #
    def run_ruby_script(command, log_status=true)
      return unless behavior == :invoke
      say_status File.basename(Thor::Util.ruby_command), command, log_status
      `#{Thor::Util.ruby_command} #{command}` unless options[:pretend]
    end

    # Run a thor command. A hash of options can be given and it's converted to 
    # switches.
    #
    # ==== Parameters
    # task<String>:: the task to be invoked
    # args<Array>:: arguments to the task
    # options<Hash>:: a hash with options used on invocation
    # log_status<Boolean>:: if false, does not log the status. True by default.
    #                       If a symbol is given, uses it as the output color.
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
      log_status = args.last.is_a?(Symbol) || [true, false].include?(args.last) ? args.pop : true
      options    = args.last.is_a?(Hash) ? args.pop : {}

      args.unshift task
      args.push Thor::Options.to_switches(options)
      command = args.join(' ').strip

      say_status :thor, command, log_status
      run "thor #{command}", false
    end

    # Removes a file at the given location.
    #
    # ==== Parameters
    # path<String>:: path of the file to be changed
    # log_status<Boolean>:: if false, does not log the status. True by default.
    #                       If a symbol is given, uses it as the output color.
    #
    # ==== Example
    #
    #   remove_file 'README'
    #   remove_file 'app/controllers/application_controller.rb'
    #
    def remove_file(path, log_status=true)
      return unless behavior == :invoke
      path  = File.expand_path(path, destination_root)
      color = log_status.is_a?(Symbol) ? log_status : :red

      say_status :remove, relative_to_original_destination_root(path), log_status
      ::FileUtils.rm_rf(path) if !options[:pretend] && File.exists?(path)
    end

    # Run a regular expression replacement on a file.
    #
    # ==== Parameters
    # path<String>:: path of the file to be changed
    # flag<Regexp|String>:: the regexp or string to be replaced
    # replacement<String>:: the replacement, can be also given as a block
    # log_status<Boolean>:: if false, does not log the status. True by default.
    #                       If a symbol is given, uses it as the output color.
    #
    # ==== Example
    #
    #   gsub_file 'app/controllers/application_controller.rb', /#\s*(filter_parameter_logging :password)/, '\1'
    #
    #   gsub_file 'README', /rake/, :green do |match|
    #     match << " no more. Use thor!"
    #   end
    #
    def gsub_file(path, flag, *args, &block)
      return unless behavior == :invoke
      log_status = args.last.is_a?(Symbol) || [ true, false ].include?(args.last) ? args.pop : true

      path = File.expand_path(path, destination_root)
      say_status :gsub, relative_to_original_destination_root(path), log_status

      unless options[:pretend]
        content = File.read(path)
        content.gsub!(flag, *args, &block)
        File.open(path, 'wb') { |file| file.write(content) }
      end
    end

    # Append text to a file.
    #
    # ==== Parameters
    # path<String>:: path of the file to be changed
    # data<String>:: the data to append to the file, can be also given as a block.
    # log_status<Boolean>:: if false, does not log the status. True by default.
    #                       If a symbol is given, uses it as the output color.
    #
    # ==== Example
    #
    #   append_file 'config/environments/test.rb', 'config.gem "rspec"'
    #
    def append_file(path, data=nil, log_status=true, &block)
      return unless behavior == :invoke
      path = File.expand_path(path, destination_root)
      say_status :append, relative_to_original_destination_root(path), log_status
      File.open(path, 'ab') { |file| file.write(data || block.call) } unless options[:pretend]
    end

    # Prepend text to a file.
    #
    # ==== Parameters
    # path<String>:: path of the file to be changed
    # data<String>:: the data to prepend to the file, can be also given as a block.
    # log_status<Boolean>:: if false, does not log the status. True by default.
    #                       If a symbol is given, uses it as the output color.
    #
    # ==== Example
    #
    #   prepend_file 'config/environments/test.rb', 'config.gem "rspec"'
    #
    def prepend_file(path, data=nil, log_status=true, &block)
      return unless behavior == :invoke
      path = File.expand_path(path, destination_root)
      say_status :prepend, relative_to_original_destination_root(path), log_status

      unless options[:pretend]
        content = data || block.call
        content << File.read(path)
        File.open(path, 'wb') { |file| file.write(content) }
      end
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
