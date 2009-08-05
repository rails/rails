$:.unshift File.expand_path(File.dirname(__FILE__))
require 'thor/base'
require 'thor/group'
require 'thor/actions'

class Thor
  class << self
    # Sets the default task when thor is executed without an explicit task to be called.
    #
    # ==== Parameters
    # meth<Symbol>:: name of the defaut task
    #
    def default_task(meth=nil)
      case meth
        when :none
          @default_task = 'help'
        when nil
          @default_task ||= from_superclass(:default_task, 'help')
        else
          @default_task = meth.to_s
      end
    end

    # Defines the usage and the description of the next task.
    #
    # ==== Parameters
    # usage<String>
    # description<String>
    #
    def desc(usage, description, options={})
      if options[:for]
        task = find_and_refresh_task(options[:for])
        task.usage = usage             if usage
        task.description = description if description
      else
        @usage, @desc = usage, description
      end
    end

    # Maps an input to a task. If you define:
    #
    #   map "-T" => "list"
    #
    # Running:
    #
    #   thor -T
    #
    # Will invoke the list task.
    #
    # ==== Parameters
    # Hash[String|Array => Symbol]:: Maps the string or the strings in the array to the given task.
    #
    def map(mappings=nil)
      @map ||= from_superclass(:map, {})

      if mappings
        mappings.each do |key, value|
          if key.respond_to?(:each)
            key.each {|subkey| @map[subkey] = value}
          else
            @map[key] = value
          end
        end
      end

      @map
    end

    # Declares the options for the next task to be declared.
    #
    # ==== Parameters
    # Hash[Symbol => Object]:: The hash key is the name of the option and the value
    # is the type of the option. Can be :string, :array, :hash, :boolean, :numeric
    # or :required (string). If you give a value, the type of the value is used.
    #
    def method_options(options=nil)
      @method_options ||= {}
      build_options(options, @method_options) if options
      @method_options
    end

    # Adds an option to the set of class options. If :for is given as option,
    # it allows you to change the options from a previous defined task.
    #
    #   def previous_task
    #     # magic
    #   end
    #
    #   method_options :foo => :bar, :for => :previous_task
    #
    #   def next_task
    #     # magic
    #   end
    #
    # ==== Parameters
    # name<Symbol>:: The name of the argument.
    # options<Hash>:: Described below.
    #
    # ==== Options
    # :desc     - Description for the argument.
    # :required - If the argument is required or not.
    # :default  - Default value for this argument. It cannot be required and have default values.
    # :aliases  - Aliases for this option.
    # :type     - The type of the argument, can be :string, :hash, :array, :numeric or :boolean.
    # :group    - The group for this options. Use by class options to output options in different levels.
    # :banner   - String to show on usage notes.
    #
    def method_option(name, options={})
      scope = if options[:for]
        find_and_refresh_task(options[:for]).options
      else
        method_options
      end

      build_option(name, options, scope)
    end

    # Parses the task and options from the given args, instantiate the class
    # and invoke the task. This method is used when the arguments must be parsed
    # from an array. If you are inside Ruby and want to use a Thor class, you
    # can simply initialize it:
    #
    #   script = MyScript.new(args, options, config)
    #   script.invoke(:task, first_arg, second_arg, third_arg)
    #
    def start(given_args=ARGV, config={})
      super do
        meth = normalize_task_name(given_args.shift)
        task = all_tasks[meth]

        if task
          args, opts = Thor::Options.split(given_args)
          config.merge!(:task_options => task.options)
        else
          args, opts = given_args, {}
        end

        task ||= Task.dynamic(meth)
        trailing = args[Range.new(arguments.size, -1)]
        new(args, opts, config).invoke(task, trailing || [])
      end
    end

    # Prints help information. If a task name is given, it shows information
    # only about the specific task.
    #
    # ==== Parameters
    # meth<String>:: An optional task name to print usage information about.
    #
    # ==== Options
    # namespace:: When true, shows the namespace in the output before the usage.
    # skip_inherited:: When true, does not show tasks from superclass.
    #
    def help(shell, meth=nil, options={})
      meth, options = nil, meth if meth.is_a?(Hash)

      if meth
        task = all_tasks[meth]
        raise UndefinedTaskError, "task '#{meth}' could not be found in namespace '#{self.namespace}'" unless task

        shell.say "Usage:"
        shell.say "  #{banner(task, options[:namespace], false)}"
        shell.say
        class_options_help(shell, "Class", :Method => task.options.map { |_, o| o })
        shell.say task.description
      else
        list = (options[:short] ? tasks : all_tasks).map do |_, task|
          item = [ banner(task, options[:namespace]) ]
          item << "# #{task.short_description}" if task.short_description
          item << " "
        end

        options[:ident] ||= 2
        if options[:short]
          shell.print_list(list, :ident => options[:ident])
        else
          shell.say "Tasks:"
          shell.print_list(list, :ident => options[:ident])
        end

        Thor::Util.thor_classes_in(self).each do |subclass|
          namespace = options[:namespace] == true || subclass.namespace.gsub(/^#{self.namespace}:/, '')
          subclass.help(shell, options.merge(:short => true, :namespace => namespace))
        end

        class_options_help(shell, "Class") unless options[:short]
      end
    end

    protected

      # The banner for this class. You can customize it if you are invoking the
      # thor class by another ways which is not the Thor::Runner. It receives
      # the task that is going to be invoked and a boolean which indicates if
      # the namespace should be displayed as arguments.
      #
      def banner(task, namespace=true, show_options=true)
        task.formatted_usage(self, namespace, show_options)
      end

      def baseclass #:nodoc:
        Thor
      end

      def create_task(meth) #:nodoc:
        if @usage && @desc
          tasks[meth.to_s] = Thor::Task.new(meth, @desc, @usage, method_options)
          @usage, @desc, @method_options = nil
          true
        elsif self.all_tasks[meth.to_s] || meth.to_sym == :method_missing
          true
        else
          puts "[WARNING] Attempted to create task #{meth.inspect} without usage or description. " <<
               "Call desc if you want this method to be available as task or declare it inside a " <<
               "no_tasks{} block. Invoked from #{caller[1].inspect}."
          false
        end
      end

      def initialize_added #:nodoc:
        class_options.merge!(method_options)
        @method_options = nil
      end

      # Receives a task name (can be nil), and try to get a map from it.
      # If a map can't be found use the sent name or the default task.
      #
      def normalize_task_name(meth) #:nodoc:
        mapping = map[meth.to_s]
        meth = mapping || meth || default_task
        meth.to_s.gsub('-','_') # treat foo-bar > foo_bar
      end
  end

  include Thor::Base

  map HELP_MAPPINGS => :help

  desc "help [TASK]", "Describe available tasks or one specific task"
  def help(task=nil)
    self.class.help(shell, task, :namespace => task && task.include?(?:))
  end
end
