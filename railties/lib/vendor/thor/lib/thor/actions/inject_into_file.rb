class Thor
  module Actions

    # Injects the given content into a file. Different from append_file,
    # prepend_file and gsub_file, this method is reversible. By this reason,
    # the flag can only be strings. gsub_file is your friend if you need to
    # deal with more complex cases.
    #
    # ==== Parameters
    # destination<String>:: Relative path to the destination root
    # data<String>:: Data to add to the file. Can be given as a block.
    # flag<String>:: Flag of where to add the changes.
    # log_status<Boolean>:: If false, does not log the status. True by default.
    #                       If a symbol is given, uses it as the output color.
    # 
    # ==== Examples
    #
    #   inject_into_file "config/environment.rb", "config.gem thor", :after => "Rails::Initializer.run do |config|\n"
    #
    #   inject_into_file "config/environment.rb", :after => "Rails::Initializer.run do |config|\n" do
    #     gems = ask "Which gems would you like to add?"
    #     gems.split(" ").map{ |gem| "  config.gem #{gem}" }.join("\n")
    #   end
    #
    def inject_into_file(destination, *args, &block)
      if block_given?
        data, flag = block, args.shift
      else
        data, flag = args.shift, args.shift
      end

      log_status = args.empty? || args.pop
      action InjectIntoFile.new(self, destination, data, flag, log_status)
    end

    class InjectIntoFile #:nodoc:
      attr_reader :base, :destination, :relative_destination, :flag, :replacement

      def initialize(base, destination, data, flag, log_status=true)
        @base, @log_status = base, log_status
        behavior, @flag = flag.keys.first, flag.values.first

        self.destination = destination
        data = data.call if data.is_a?(Proc)

        @replacement = if behavior == :after
          @flag + data
        else
          data + @flag
        end
      end

      def invoke!
        say_status :inject
        replace!(flag, replacement)
      end

      def revoke!
        say_status :deinject
        replace!(replacement, flag)
      end

      protected

        # Sets the destination value from a relative destination value. The
        # relative destination is kept to be used in output messages.
        #
        def destination=(destination)
          if destination
            @destination = ::File.expand_path(destination.to_s, base.destination_root)
            @relative_destination = base.relative_to_absolute_root(@destination)
          end
        end

        # Shortcut to say_status shell method.
        #
        def say_status(status)
          base.shell.say_status status, relative_destination, @log_status
        end

        # Adds the content to the file.
        #
        def replace!(regexp, string)
          unless base.options[:pretend]
            content = File.read(destination)
            content.gsub!(regexp, string)
            File.open(destination, 'wb') { |file| file.write(content) }
          end
        end

    end
  end
end
