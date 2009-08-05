class Thor
  module Invocation
    def self.included(base) #:nodoc:
      base.extend ClassMethods
    end

    module ClassMethods
      # Prepare for class methods invocations. This method must return a klass to
      # have the invoked class options showed in help messages in generators.
      #
      def prepare_for_invocation(key, name) #:nodoc:
        case name
          when Symbol, String
            Thor::Util.namespace_to_thor_class_and_task(name.to_s, false)
          else
            name
        end
      end
    end

    # Make initializer aware of invocations and the initializer proc.
    #
    def initialize(args=[], options={}, config={}, &block) #:nodoc:
      @_invocations = config[:invocations] || Hash.new { |h,k| h[k] = [] }
      @_initializer = [ args, options, config ]
      super
    end

    # Receives a name and invokes it. The name can be a string (either "task" or
    # "namespace:task"), a Thor::Task, a Class or a Thor instance. If the task
    # cannot be guessed by name, it can also be supplied as second argument.
    #
    # You can also supply the arguments, options and configuration values for
    # the task to be invoked, if none is given, the same values used to
    # initialize the invoker are used to initialize the invoked.
    #
    # ==== Examples
    #
    #   class A < Thor
    #     def foo
    #       invoke :bar
    #       invoke "b:hello", ["José"]
    #     end
    #
    #     def bar
    #       invoke "b:hello", ["José"]
    #     end
    #   end
    #
    #   class B < Thor
    #     def hello(name)
    #       puts "hello #{name}"
    #     end
    #   end
    #
    # You can notice that the method "foo" above invokes two tasks: "bar",
    # which belongs to the same class and "hello" which belongs to the class B.
    #
    # By using an invocation system you ensure that a task is invoked only once.
    # In the example above, invoking "foo" will invoke "b:hello" just once, even
    # if it's invoked later by "bar" method.
    #
    # When class A invokes class B, all arguments used on A initialization are
    # supplied to B. This allows lazy parse of options. Let's suppose you have
    # some rspec tasks:
    #
    #   class Rspec < Thor::Group
    #     class_option :mock_framework, :type => :string, :default => :rr
    #
    #     def invoke_mock_framework
    #       invoke "rspec:#{options[:mock_framework]}"
    #     end
    #   end
    #
    # As you noticed, it invokes the given mock framework, which might have its
    # own options:
    #
    #   class Rspec::RR < Thor::Group
    #     class_option :style, :type => :string, :default => :mock
    #   end
    #
    # Since it's not rspec concern to parse mock framework options, when RR
    # is invoked all options are parsed again, so RR can extract only the options
    # that it's going to use.
    #
    # If you want Rspec::RR to be initialized with its own set of options, you
    # have to do that explicitely:
    #
    #   invoke "rspec:rr", [], :style => :foo
    #
    # Besides giving an instance, you can also give a class to invoke:
    #
    #   invoke Rspec::RR, [], :style => :foo
    #
    def invoke(name=nil, task=nil, args=nil, opts=nil, config=nil)
      task, args, opts, config = nil, task, args, opts if task.nil? || task.is_a?(Array)
      args, opts, config = nil, args, opts if args.is_a?(Hash)

      object, task    = _prepare_for_invocation(name, task)
      klass, instance = _initialize_klass_with_initializer(object, args, opts, config)

      method_args = []
      current = @_invocations[klass]

      iterator = proc do |_, task|
        unless current.include?(task.name)
          current << task.name
          task.run(instance, method_args)
        end
      end

      if task
        args ||= []
        method_args = args[Range.new(klass.arguments.size, -1)] || []
        iterator.call(nil, task)
      else
        klass.all_tasks.map(&iterator)
      end
    end

    protected

      # Configuration values that are shared between invocations.
      #
      def _shared_configuration #:nodoc:
        { :invocations => @_invocations }
      end

      # Prepare for invocation in the instance level. In this case, we have to
      # take into account that a just a task name from the current class was
      # given or even a Thor::Task object.
      #
      def _prepare_for_invocation(name, sent_task=nil) #:nodoc:
        if name.is_a?(Thor::Task)
          task = name
        elsif task = self.class.all_tasks[name.to_s]
          object = self
        else
          object, task = self.class.prepare_for_invocation(nil, name)
          task ||= sent_task
        end

        # If the object was not set, use self and use the name as task.
        object, task = self, name unless object
        return object, _validate_task(object, task)
      end

      # Check if the object given is a Thor class object and get a task object
      # for it.
      #
      def _validate_task(object, task) #:nodoc:
        klass = object.is_a?(Class) ? object : object.class
        raise "Expected Thor class, got #{klass}" unless klass <= Thor::Base

        task ||= klass.default_task if klass <= Thor
        task = klass.all_tasks[task.to_s] || Task.dynamic(task) if task && !task.is_a?(Thor::Task)
        task
      end

      # Initialize klass using values stored in the @_initializer.
      #
      def _initialize_klass_with_initializer(object, args, opts, config) #:nodoc:
        if object.is_a?(Class)
          klass = object

          stored_args, stored_opts, stored_config = @_initializer
          args ||= stored_args.dup
          opts ||= stored_opts.dup

          config ||= {}
          config = stored_config.merge(_shared_configuration).merge!(config)
          [ klass, klass.new(args, opts, config) ]
        else
          [ object.class, object ]
        end
      end
  end
end
