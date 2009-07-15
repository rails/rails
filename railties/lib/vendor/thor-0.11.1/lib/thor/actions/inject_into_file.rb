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
    # config<Hash>:: give :verbose => false to not log the status and the flag
    #                for injection (:after or :before).
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
        data, config = block, args.shift
      else
        data, config = args.shift, args.shift
      end

      log_status = args.empty? || args.pop
      action InjectIntoFile.new(self, destination, data, config)
    end

    class InjectIntoFile #:nodoc:
      attr_reader :base, :destination, :relative_destination, :flag, :replacement, :config

      def initialize(base, destination, data, config)
        @base, @config = base, { :verbose => true }.merge(config)

        self.destination = destination
        data = data.call if data.is_a?(Proc)

        @replacement = if @config.key?(:after)
          @flag = @config.delete(:after)
          @flag + data
        else
          @flag = @config.delete(:before)
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
            @relative_destination = base.relative_to_original_destination_root(@destination)
          end
        end

        # Shortcut to say_status shell method.
        #
        def say_status(status)
          base.shell.say_status status, relative_destination, config[:verbose]
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
