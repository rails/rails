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

    protected

      # The banner for this class. You can customize it if you are invoking the
      # thor class by another means which is not the Thor::Runner.
      #
      def banner #:nodoc:
        "#{self.namespace} #{self.arguments.map {|a| a.usage }.join(' ')}"
      end

      def baseclass #:nodoc:
        Thor::Group
      end

      def create_task(meth) #:nodoc:
        tasks[meth.to_s] = Thor::Task.new(meth, nil, nil, nil)
      end
  end

  include Thor::Base
end
