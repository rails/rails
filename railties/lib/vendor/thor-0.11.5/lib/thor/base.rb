require 'thor/core_ext/hash_with_indifferent_access'
require 'thor/core_ext/ordered_hash'
require 'thor/error'
require 'thor/shell'
require 'thor/invocation'
require 'thor/parser'
require 'thor/task'
require 'thor/util'

class Thor
  # Shortcuts for help.
  HELP_MAPPINGS       = %w(-h -? --help -D)

  # Thor methods that should not be overwritten by the user.
  THOR_RESERVED_WORDS = %w(invoke shell options behavior root destination_root relative_root
                           action add_file create_file in_root inside run run_ruby_script)

  module Base
    attr_accessor :options

    # It receives arguments in an Array and two hashes, one for options and
    # other for configuration.
    #
    # Notice that it does not check if all required arguments were supplied.
    # It should be done by the parser.
    #
    # ==== Parameters
    # args<Array[Object]>:: An array of objects. The objects are applied to their
    #                       respective accessors declared with <tt>argument</tt>.
    #
    # options<Hash>:: An options hash that will be available as self.options.
    #                 The hash given is converted to a hash with indifferent
    #                 access, magic predicates (options.skip?) and then frozen.
    #
    # config<Hash>:: Configuration for this Thor class.
    #
    def initialize(args=[], options={}, config={})
      Thor::Arguments.parse(self.class.arguments, args).each do |key, value|
        send("#{key}=", value)
      end

      parse_options = self.class.class_options

      if options.is_a?(Array)
        task_options  = config.delete(:task_options) # hook for start
        parse_options = parse_options.merge(task_options) if task_options
        array_options, hash_options = options, {}
      else
        array_options, hash_options = [], options
      end

      options = Thor::Options.parse(parse_options, array_options)
      self.options = Thor::CoreExt::HashWithIndifferentAccess.new(options).merge!(hash_options)
      self.options.freeze
    end

    class << self
      def included(base) #:nodoc:
        base.send :extend,  ClassMethods
        base.send :include, Invocation
        base.send :include, Shell
      end

      # Returns the classes that inherits from Thor or Thor::Group.
      #
      # ==== Returns
      # Array[Class]
      #
      def subclasses
        @subclasses ||= []
      end

      # Returns the files where the subclasses are kept.
      #
      # ==== Returns
      # Hash[path<String> => Class]
      #
      def subclass_files
        @subclass_files ||= Hash.new{ |h,k| h[k] = [] }
      end

      # Whenever a class inherits from Thor or Thor::Group, we should track the
      # class and the file on Thor::Base. This is the method responsable for it.
      #
      def register_klass_file(klass) #:nodoc:
        file = caller[1].match(/(.*):\d+/)[1]
        Thor::Base.subclasses << klass unless Thor::Base.subclasses.include?(klass)

        file_subclasses = Thor::Base.subclass_files[File.expand_path(file)]
        file_subclasses << klass unless file_subclasses.include?(klass)
      end
    end

    module ClassMethods
      # Adds an argument to the class and creates an attr_accessor for it.
      #
      # Arguments are different from options in several aspects. The first one
      # is how they are parsed from the command line, arguments are retrieved
      # from position:
      #
      #   thor task NAME
      #
      # Instead of:
      #
      #   thor task --name=NAME
      #
      # Besides, arguments are used inside your code as an accessor (self.argument),
      # while options are all kept in a hash (self.options).
      #
      # Finally, arguments cannot have type :default or :boolean but can be
      # optional (supplying :optional => :true or :required => false), although
      # you cannot have a required argument after a non-required argument. If you
      # try it, an error is raised.
      #
      # ==== Parameters
      # name<Symbol>:: The name of the argument.
      # options<Hash>:: Described below.
      #
      # ==== Options
      # :desc     - Description for the argument.
      # :required - If the argument is required or not.
      # :optional - If the argument is optional or not.
      # :type     - The type of the argument, can be :string, :hash, :array, :numeric.
      # :default  - Default value for this argument. It cannot be required and have default values.
      # :banner   - String to show on usage notes.
      #
      # ==== Errors
      # ArgumentError:: Raised if you supply a required argument after a non required one.
      #
      def argument(name, options={})
        is_thor_reserved_word?(name, :argument)
        no_tasks { attr_accessor name }

        required = if options.key?(:optional)
          !options[:optional]
        elsif options.key?(:required)
          options[:required]
        else
          options[:default].nil?
        end

        remove_argument name

        arguments.each do |argument|
          next if argument.required?
          raise ArgumentError, "You cannot have #{name.to_s.inspect} as required argument after " <<
                               "the non-required argument #{argument.human_name.inspect}."
        end if required

        arguments << Thor::Argument.new(name, options[:desc], required, options[:type],
                                              options[:default], options[:banner])
      end

      # Returns this class arguments, looking up in the ancestors chain.
      #
      # ==== Returns
      # Array[Thor::Argument]
      #
      def arguments
        @arguments ||= from_superclass(:arguments, [])
      end

      # Adds a bunch of options to the set of class options.
      #
      #   class_options :foo => false, :bar => :required, :baz => :string
      #
      # If you prefer more detailed declaration, check class_option.
      #
      # ==== Parameters
      # Hash[Symbol => Object]
      #
      def class_options(options=nil)
        @class_options ||= from_superclass(:class_options, {})
        build_options(options, @class_options) if options
        @class_options
      end

      # Adds an option to the set of class options
      #
      # ==== Parameters
      # name<Symbol>:: The name of the argument.
      # options<Hash>:: Described below.
      #
      # ==== Options
      # :desc     - Description for the argument.
      # :required - If the argument is required or not.
      # :default  - Default value for this argument.
      # :group    - The group for this options. Use by class options to output options in different levels.
      # :aliases  - Aliases for this option.
      # :type     - The type of the argument, can be :string, :hash, :array, :numeric or :boolean.
      # :banner   - String to show on usage notes.
      #
      def class_option(name, options={})
        build_option(name, options, class_options)
      end

      # Removes a previous defined argument. If :undefine is given, undefine
      # accessors as well.
      #
      # ==== Paremeters
      # names<Array>:: Arguments to be removed
      #
      # ==== Examples
      #
      #   remove_argument :foo
      #   remove_argument :foo, :bar, :baz, :undefine => true
      #
      def remove_argument(*names)
        options = names.last.is_a?(Hash) ? names.pop : {}

        names.each do |name|
          arguments.delete_if { |a| a.name == name.to_s }
          undef_method name, "#{name}=" if options[:undefine]
        end
      end

      # Removes a previous defined class option.
      #
      # ==== Paremeters
      # names<Array>:: Class options to be removed
      #
      # ==== Examples
      #
      #   remove_class_option :foo
      #   remove_class_option :foo, :bar, :baz
      #
      def remove_class_option(*names)
        names.each do |name|
          class_options.delete(name)
        end
      end

      # Defines the group. This is used when thor list is invoked so you can specify
      # that only tasks from a pre-defined group will be shown. Defaults to standard.
      #
      # ==== Parameters
      # name<String|Symbol>
      #
      def group(name=nil)
        case name
          when nil
            @group ||= from_superclass(:group, 'standard')
          else
            @group = name.to_s
        end
      end

      # Returns the tasks for this Thor class.
      #
      # ==== Returns
      # OrderedHash:: An ordered hash with tasks names as keys and Thor::Task
      #               objects as values.
      #
      def tasks
        @tasks ||= Thor::CoreExt::OrderedHash.new
      end

      # Returns the tasks for this Thor class and all subclasses.
      #
      # ==== Returns
      # OrderedHash:: An ordered hash with tasks names as keys and Thor::Task
      #               objects as values.
      #
      def all_tasks
        @all_tasks ||= from_superclass(:all_tasks, Thor::CoreExt::OrderedHash.new)
        @all_tasks.merge(tasks)
      end

      # Removes a given task from this Thor class. This is usually done if you
      # are inheriting from another class and don't want it to be available
      # anymore.
      #
      # By default it only remove the mapping to the task. But you can supply
      # :undefine => true to undefine the method from the class as well.
      #
      # ==== Parameters
      # name<Symbol|String>:: The name of the task to be removed
      # options<Hash>:: You can give :undefine => true if you want tasks the method
      #                 to be undefined from the class as well.
      #
      def remove_task(*names)
        options = names.last.is_a?(Hash) ? names.pop : {}

        names.each do |name|
          tasks.delete(name.to_s)
          all_tasks.delete(name.to_s)
          undef_method name if options[:undefine]
        end
      end

      # All methods defined inside the given block are not added as tasks.
      #
      # So you can do:
      #
      #   class MyScript < Thor
      #     no_tasks do
      #       def this_is_not_a_task
      #       end
      #     end
      #   end
      #
      # You can also add the method and remove it from the task list:
      #
      #   class MyScript < Thor
      #     def this_is_not_a_task
      #     end
      #     remove_task :this_is_not_a_task
      #   end
      #
      def no_tasks
        @no_tasks = true
        yield
        @no_tasks = false
      end

      # Sets the namespace for the Thor or Thor::Group class. By default the
      # namespace is retrieved from the class name. If your Thor class is named
      # Scripts::MyScript, the help method, for example, will be called as:
      #
      #   thor scripts:my_script -h
      #
      # If you change the namespace:
      #
      #   namespace :my_scripts
      #
      # You change how your tasks are invoked:
      #
      #   thor my_scripts -h
      #
      # Finally, if you change your namespace to default:
      #
      #   namespace :default
      #
      # Your tasks can be invoked with a shortcut. Instead of:
      #
      #   thor :my_task
      #
      def namespace(name=nil)
        case name
          when nil
            @namespace ||= Thor::Util.namespace_from_thor_class(self, false)
          else
            @namespace = name.to_s
        end
      end

      # Default way to start generators from the command line.
      #
      def start(given_args=ARGV, config={})
        config[:shell] ||= Thor::Base.shell.new
        yield
      rescue Thor::Error => e
        if given_args.include?("--debug")
          raise e
        else
          config[:shell].error e.message
        end
      end

      protected

        # Prints the class options per group. If an option does not belong to
        # any group, it uses the ungrouped name value. This method provide to
        # hooks to add extra options, one of them if the third argument called
        # extra_group that should be a hash in the format :group => Array[Options].
        #
        # The second is by returning a lambda used to print values. The lambda
        # requires two options: the group name and the array of options.
        #
        def class_options_help(shell, ungrouped_name=nil, extra_group=nil) #:nodoc:
          groups = {}

          class_options.each do |_, value|
            groups[value.group] ||= []
            groups[value.group] << value
          end

          printer = proc do |group_name, options|
            list = []
            padding = options.collect{ |o| o.aliases.size  }.max.to_i * 4

            options.each do |option|
              item = [ option.usage(padding) ]
              item.push(option.description ? "# #{option.description}" : "")

              list << item
              list << [ "", "# Default: #{option.default}" ] if option.show_default?
            end

            unless list.empty?
              shell.say(group_name ? "#{group_name} options:" : "Options:")
              shell.print_table(list, :ident => 2)
              shell.say ""
            end
          end

          # Deal with default group
          global_options = groups.delete(nil) || []
          printer.call(ungrouped_name, global_options) if global_options

          # Print all others
          groups = extra_group.merge(groups) if extra_group
          groups.each(&printer)
          printer
        end

        # Raises an error if the word given is a Thor reserved word.
        #
        def is_thor_reserved_word?(word, type) #:nodoc:
          return false unless THOR_RESERVED_WORDS.include?(word.to_s)
          raise "#{word.inspect} is a Thor reserved word and cannot be defined as #{type}"
        end

        # Build an option and adds it to the given scope.
        #
        # ==== Parameters
        # name<Symbol>:: The name of the argument.
        # options<Hash>:: Described in both class_option and method_option.
        #
        def build_option(name, options, scope) #:nodoc:
          scope[name] = Thor::Option.new(name, options[:desc], options[:required],
                                               options[:type], options[:default], options[:banner],
                                               options[:group], options[:aliases])
        end

        # Receives a hash of options, parse them and add to the scope. This is a
        # fast way to set a bunch of options:
        #
        #   build_options :foo => true, :bar => :required, :baz => :string
        #
        # ==== Parameters
        # Hash[Symbol => Object]
        #
        def build_options(options, scope) #:nodoc:
          options.each do |key, value|
            scope[key] = Thor::Option.parse(key, value)
          end
        end

        # Finds a task with the given name. If the task belongs to the current
        # class, just return it, otherwise dup it and add the fresh copy to the
        # current task hash.
        #
        def find_and_refresh_task(name) #:nodoc:
          task = if task = tasks[name.to_s]
            task
          elsif task = all_tasks[name.to_s]
            tasks[name.to_s] = task.clone
          else
            raise ArgumentError, "You supplied :for => #{name.inspect}, but the task #{name.inspect} could not be found."
          end
        end

        # Everytime someone inherits from a Thor class, register the klass
        # and file into baseclass.
        #
        def inherited(klass)
          Thor::Base.register_klass_file(klass)
        end

        # Fire this callback whenever a method is added. Added methods are
        # tracked as tasks by invoking the create_task method.
        #
        def method_added(meth)
          meth = meth.to_s

          if meth == "initialize"
            initialize_added
            return
          end

          # Return if it's not a public instance method
          return unless public_instance_methods.include?(meth) ||
                        public_instance_methods.include?(meth.to_sym)

          return if @no_tasks || !create_task(meth)

          is_thor_reserved_word?(meth, :task)
          Thor::Base.register_klass_file(self)
        end

        # Retrieves a value from superclass. If it reaches the baseclass,
        # returns default.
        #
        def from_superclass(method, default=nil)
          if self == baseclass || !superclass.respond_to?(method, true)
            default
          else
            value = superclass.send(method)
            value.dup if value
          end
        end

        # SIGNATURE: Sets the baseclass. This is where the superclass lookup
        # finishes.
        def baseclass #:nodoc:
        end

        # SIGNATURE: Creates a new task if valid_task? is true. This method is
        # called when a new method is added to the class.
        def create_task(meth) #:nodoc:
        end

        # SIGNATURE: Defines behavior when the initialize method is added to the
        # class.
        def initialize_added #:nodoc:
        end
    end
  end
end
