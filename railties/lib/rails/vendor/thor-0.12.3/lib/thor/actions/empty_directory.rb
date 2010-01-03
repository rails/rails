class Thor
  module Actions

    # Creates an empty directory.
    #
    # ==== Parameters
    # destination<String>:: the relative path to the destination root.
    # config<Hash>:: give :verbose => false to not log the status.
    #
    # ==== Examples
    #
    #   empty_directory "doc"
    #
    def empty_directory(destination, config={})
      action EmptyDirectory.new(self, destination, config)
    end

    # Class which holds create directory logic. This is the base class for
    # other actions like create_file and directory.
    #
    # This implementation is based in Templater actions, created by Jonas Nicklas
    # and Michael S. Klishin under MIT LICENSE.
    #
    class EmptyDirectory #:nodoc:
      attr_reader :base, :destination, :given_destination, :relative_destination, :config

      # Initializes given the source and destination.
      #
      # ==== Parameters
      # base<Thor::Base>:: A Thor::Base instance
      # source<String>:: Relative path to the source of this file
      # destination<String>:: Relative path to the destination of this file
      # config<Hash>:: give :verbose => false to not log the status.
      #
      def initialize(base, destination, config={})
        @base, @config   = base, { :verbose => true }.merge(config)
        self.destination = destination
      end

      # Checks if the destination file already exists.
      #
      # ==== Returns
      # Boolean:: true if the file exists, false otherwise.
      #
      def exists?
        ::File.exists?(destination)
      end

      def invoke!
        invoke_with_conflict_check do
          ::FileUtils.mkdir_p(destination)
        end
      end

      def revoke!
        say_status :remove, :red
        ::FileUtils.rm_rf(destination) if !pretend? && exists?
        given_destination
      end

      protected

        # Shortcut for pretend.
        #
        def pretend?
          base.options[:pretend]
        end

        # Sets the absolute destination value from a relative destination value.
        # It also stores the given and relative destination. Let's suppose our
        # script is being executed on "dest", it sets the destination root to
        # "dest". The destination, given_destination and relative_destination
        # are related in the following way:
        #
        #   inside "bar" do
        #     empty_directory "baz"
        #   end
        #
        #   destination          #=> dest/bar/baz
        #   relative_destination #=> bar/baz
        #   given_destination    #=> baz
        #
        def destination=(destination)
          if destination
            @given_destination = convert_encoded_instructions(destination.to_s)
            @destination = ::File.expand_path(@given_destination, base.destination_root)
            @relative_destination = base.relative_to_original_destination_root(@destination)
          end
        end

        # Filenames in the encoded form are converted. If you have a file:
        #
        #   %class_name%.rb
        #
        # It gets the class name from the base and replace it:
        #
        #   user.rb
        #
        def convert_encoded_instructions(filename)
          filename.gsub(/%(.*?)%/) do |string|
            instruction = $1.strip
            base.respond_to?(instruction) ? base.send(instruction) : string
          end
        end

        # Receives a hash of options and just execute the block if some
        # conditions are met.
        #
        def invoke_with_conflict_check(&block)
          if exists?
            on_conflict_behavior(&block)
          else
            say_status :create, :green
            block.call unless pretend?
          end

          destination
        end

        # What to do when the destination file already exists.
        #
        def on_conflict_behavior(&block)
          say_status :exist, :blue
        end

        # Shortcut to say_status shell method.
        #
        def say_status(status, color)
          base.shell.say_status status, relative_destination, color if config[:verbose]
        end

    end
  end
end
