class Thor
  class Task < Struct.new(:name, :description, :usage, :options)

    # Creates a dynamic task. Dynamic tasks are created on demand to allow method
    # missing calls (since a method missing does not have a task object for it).
    #
    def self.dynamic(name)
      new(name, "A dynamically-generated task", name.to_s)
    end

    def initialize(name, description, usage, options=nil)
      super(name.to_s, description, usage, options || {})
    end

    def initialize_copy(other) #:nodoc:
      super(other)
      self.options = other.options.dup if other.options
    end

    def short_description
      description.split("\n").first if description
    end

    # By default, a task invokes a method in the thor class. You can change this
    # implementation to create custom tasks.
    #
    def run(instance, args=[])
      raise UndefinedTaskError, "the '#{name}' task of #{instance.class} is private" unless public_method?(instance)
      instance.send(name, *args)
    rescue ArgumentError => e
      parse_argument_error(instance, e, caller)
    rescue NoMethodError => e
      parse_no_method_error(instance, e)
    end

    # Returns the formatted usage. If a class is given, the class arguments are
    # injected in the usage.
    #
    def formatted_usage(klass=nil, namespace=false, show_options=true)
      formatted = ''

      formatted = if namespace.is_a?(String)
        "#{namespace}:"
      elsif klass && namespace
        "#{klass.namespace.gsub(/^default/,'')}:"
      else
        ""
      end

      formatted << formatted_arguments(klass)
      formatted << " #{formatted_options}" if show_options
      formatted.strip!
      formatted
    end

    # Injects the class arguments into the task usage.
    #
    def formatted_arguments(klass)
      if klass && !klass.arguments.empty?
        usage.to_s.gsub(/^#{name}/) do |match|
          match << " " << klass.arguments.map{ |a| a.usage }.join(' ')
        end
      else
        usage.to_s
      end
    end

    # Returns the options usage for this task.
    #
    def formatted_options
      @formatted_options ||= options.map{ |_, o| o.usage }.sort.join(" ")
    end

    protected

      # Given a target, checks if this class name is not a private/protected method.
      #
      def public_method?(instance) #:nodoc:
        collection = instance.private_methods + instance.protected_methods
        !(collection).include?(name.to_s) && !(collection).include?(name.to_sym) # For Ruby 1.9
      end

      # Clean everything that comes from the Thor gempath and remove the caller.
      #
      def sans_backtrace(backtrace, caller) #:nodoc:
        dirname = /^#{Regexp.escape(File.dirname(__FILE__))}/
        saned  = backtrace.reject { |frame| frame =~ dirname }
        saned -= caller
      end

      def parse_argument_error(instance, e, caller) #:nodoc:
        backtrace = sans_backtrace(e.backtrace, caller)

        if backtrace.empty? && e.message =~ /wrong number of arguments/
          if instance.is_a?(Thor::Group)
            raise e, "'#{name}' was called incorrectly. Are you sure it has arity equals to 0?"
          else
            raise InvocationError, "'#{name}' was called incorrectly. Call as " <<
                                   "'#{formatted_usage(instance.class, true)}'"
          end
        else
          raise e
        end
      end

      def parse_no_method_error(instance, e) #:nodoc:
        if e.message =~ /^undefined method `#{name}' for #{Regexp.escape(instance.to_s)}$/
          raise UndefinedTaskError, "The #{instance.class.namespace} namespace " <<
                                    "doesn't have a '#{name}' task"
        else
          raise e
        end
      end

  end
end
