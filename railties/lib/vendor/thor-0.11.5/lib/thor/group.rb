# Thor has a special class called Thor::Group. The main difference to Thor class
# is that it invokes all tasks at once. It also include some methods that allows
# invocations to be done at the class method, which are not available to Thor
# tasks.
#
class Thor::Group
  class << self
    # The descrition for this Thor::Group. If none is provided, but a source root
    # exists, tries to find the USAGE one folder above it, otherwise searches
    # in the superclass.
    #
    # ==== Parameters
    # description<String>:: The description for this Thor::Group.
    #
    def desc(description=nil)
      case description
        when nil
          @desc ||= from_superclass(:desc, nil)
        else
          @desc = description
      end
    end

    # Start works differently in Thor::Group, it simply invokes all tasks
    # inside the class.
    #
    def start(given_args=ARGV, config={})
      super do
        if Thor::HELP_MAPPINGS.include?(given_args.first)
          help(config[:shell])
          return
        end

        args, opts = Thor::Options.split(given_args)
        new(args, opts, config).invoke
      end
    end

    # Prints help information.
    #
    # ==== Options
    # short:: When true, shows only usage.
    #
    def help(shell, options={})
      if options[:short]
        shell.say banner
      else
        shell.say "Usage:"
        shell.say "  #{banner}"
        shell.say
        class_options_help(shell)
        shell.say self.desc if self.desc
      end
    end

    # Stores invocations for this class merging with superclass values.
    #
    def invocations #:nodoc:
      @invocations ||= from_superclass(:invocations, {})
    end

    # Stores invocation blocks used on invoke_from_option.
    #
    def invocation_blocks #:nodoc:
      @invocation_blocks ||= from_superclass(:invocation_blocks, {})
    end

    # Invoke the given namespace or class given. It adds an instance
    # method that will invoke the klass and task. You can give a block to
    # configure how it will be invoked.
    #
    # The namespace/class given will have its options showed on the help
    # usage. Check invoke_from_option for more information.
    #
    def invoke(*names, &block)
      options = names.last.is_a?(Hash) ? names.pop : {}
      verbose = options.fetch(:verbose, :white)

      names.each do |name|
        invocations[name] = false
        invocation_blocks[name] = block if block_given?

        class_eval <<-METHOD, __FILE__, __LINE__
          def _invoke_#{name.to_s.gsub(/\W/, '_')}
            klass, task = self.class.prepare_for_invocation(nil, #{name.inspect})

            if klass
              say_status :invoke, #{name.inspect}, #{verbose.inspect}
              block = self.class.invocation_blocks[#{name.inspect}]
              _invoke_for_class_method klass, task, &block
            else
              say_status :error, %(#{name.inspect} [not found]), :red
            end
          end
        METHOD
      end
    end

    # Invoke a thor class based on the value supplied by the user to the
    # given option named "name". A class option must be created before this
    # method is invoked for each name given.
    #
    # ==== Examples
    #
    #   class GemGenerator < Thor::Group
    #     class_option :test_framework, :type => :string
    #     invoke_from_option :test_framework
    #   end
    #
    # ==== Boolean options
    #
    # In some cases, you want to invoke a thor class if some option is true or
    # false. This is automatically handled by invoke_from_option. Then the
    # option name is used to invoke the generator.
    #
    # ==== Preparing for invocation
    #
    # In some cases you want to customize how a specified hook is going to be
    # invoked. You can do that by overwriting the class method
    # prepare_for_invocation. The class method must necessarily return a klass
    # and an optional task.
    #
    # ==== Custom invocations
    #
    # You can also supply a block to customize how the option is giong to be
    # invoked. The block receives two parameters, an instance of the current
    # class and the klass to be invoked.
    #
    def invoke_from_option(*names, &block)
      options = names.last.is_a?(Hash) ? names.pop : {}
      verbose = options.fetch(:verbose, :white)

      names.each do |name|
        unless class_options.key?(name)
          raise ArgumentError, "You have to define the option #{name.inspect} " << 
                               "before setting invoke_from_option."
        end

        invocations[name] = true
        invocation_blocks[name] = block if block_given?

        class_eval <<-METHOD, __FILE__, __LINE__
          def _invoke_from_option_#{name.to_s.gsub(/\W/, '_')}
            return unless options[#{name.inspect}]

            value = options[#{name.inspect}]
            value = #{name.inspect} if TrueClass === value
            klass, task = self.class.prepare_for_invocation(#{name.inspect}, value)

            if klass
              say_status :invoke, value, #{verbose.inspect}
              block = self.class.invocation_blocks[#{name.inspect}]
              _invoke_for_class_method klass, task, &block
            else
              say_status :error, %(\#{value} [not found]), :red
            end
          end
        METHOD
      end
    end

    # Remove a previously added invocation.
    #
    # ==== Examples
    #
    #   remove_invocation :test_framework
    #
    def remove_invocation(*names)
      names.each do |name|
        remove_task(name)
        remove_class_option(name)
        invocations.delete(name)
        invocation_blocks.delete(name)
      end
    end

    # Overwrite class options help to allow invoked generators options to be
    # shown recursively when invoking a generator.
    #
    def class_options_help(shell, ungrouped_name=nil, extra_group=nil) #:nodoc:
      group_options = {}

      get_options_from_invocations(group_options, class_options) do |klass|
        klass.send(:get_options_from_invocations, group_options, class_options)
      end

      group_options.merge!(extra_group) if extra_group
      super(shell, ungrouped_name, group_options)
    end

    # Get invocations array and merge options from invocations. Those
    # options are added to group_options hash. Options that already exists
    # in base_options are not added twice.
    #
    def get_options_from_invocations(group_options, base_options) #:nodoc:
      invocations.each do |name, from_option|
        value = if from_option
          option = class_options[name]
          option.type == :boolean ? name : option.default
        else
          name
        end
        next unless value

        klass, task = prepare_for_invocation(name, value)
        next unless klass && klass.respond_to?(:class_options)

        value = value.to_s
        human_name = value.respond_to?(:classify) ? value.classify : value

        group_options[human_name] ||= []
        group_options[human_name] += klass.class_options.values.select do |option|
          base_options[option.name.to_sym].nil? && option.group.nil? &&
          !group_options.values.flatten.any? { |i| i.name == option.name }
        end

        yield klass if block_given?
      end
    end

    protected

      # The banner for this class. You can customize it if you are invoking the
      # thor class by another ways which is not the Thor::Runner.
      #
      def banner
        "#{self.namespace} #{self.arguments.map {|a| a.usage }.join(' ')}"
      end

      def baseclass #:nodoc:
        Thor::Group
      end

      def create_task(meth) #:nodoc:
        tasks[meth.to_s] = Thor::Task.new(meth, nil, nil, nil)
        true
      end
  end

  include Thor::Base

  protected

    # Shortcut to invoke with padding and block handling. Use internally by
    # invoke and invoke_from_option class methods.
    #
    def _invoke_for_class_method(klass, task=nil, *args, &block) #:nodoc:
      shell.padding += 1

      result = if block_given?
        if block.arity == 2
          block.call(self, klass)
        else
          block.call(self, klass, task)
        end
      else
        invoke klass, task, *args
      end

      shell.padding -= 1
      result
    end
end
