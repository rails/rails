class Thor
  module Actions

    # This is the base class for templater actions, ie. that copies something
    # from some directory (source) to another (destination).
    #
    # This implementation is completely based in Templater actions, created
    # by Jonas Nicklas and Michael S. Klishin under MIT LICENSE.
    #
    class Templater #:nodoc:
      attr_reader :base, :source, :destination, :given_destination, :relative_destination, :config

      # Initializes given the source and destination.
      #
      # ==== Parameters
      # base<Thor::Base>:: A Thor::Base instance
      # source<String>:: Relative path to the source of this file
      # destination<String>:: Relative path to the destination of this file
      # config<Hash>:: give :verbose => false to not log the status.
      #
      def initialize(base, source, destination, config={})
        @base, @config = base, { :verbose => true }.merge(config)
        self.source = source
        self.destination = destination
      end

      # Returns the contents of the source file as a String. If render is
      # available, a diff option is shown in the file collision menu.
      #
      # ==== Returns
      # String:: The source file.
      #
      # def render
      # end

      # Checks if the destination file already exists.
      #
      # ==== Returns
      # Boolean:: true if the file exists, false otherwise.
      #
      def exists?
        ::File.exists?(destination)
      end

      # Checks if the content of the file at the destination is identical to the rendered result.
      #
      # ==== Returns
      # Boolean:: true if it is identical, false otherwise.
      #
      def identical?
        exists? && (is_not_comparable? || ::File.read(destination) == render)
      end

      # Invokes the action. By default it adds to the file the content rendered,
      # but you can modify in the subclass.
      #
      def invoke!
        invoke_with_options!(base.options.merge(config)) do
          ::FileUtils.mkdir_p(::File.dirname(destination))
          ::File.open(destination, 'w'){ |f| f.write render }
        end
      end

      # Revokes the action.
      #
      def revoke!
        say_status :remove, :red
        ::FileUtils.rm_rf(destination) if !pretend? && exists?
      end

      protected

        # Shortcut for pretend.
        #
        def pretend?
          base.options[:pretend]
        end

        # A templater is comparable if responds to render. In such cases, we have
        # to show the conflict menu to the user unless the files are identical.
        #
        def is_not_comparable?
          !respond_to?(:render)
        end

        # Sets the absolute source value from a relative source value. Notice
        # that we need to take into consideration both the source_root as the
        # relative_root.
        #
        # Let's suppose that we are on the directory "dest", with source root set
        # to "source" and with the following scenario:
        #
        #   inside "bar" do
        #     copy_file "baz.rb"
        #   end
        #
        # In this case, the user wants to copy the file at "source/bar/baz.rb"
        # to "dest/bar/baz.rb". If we don't take into account the relative_root
        # (in this case, "bar"), it would copy the contents at "source/baz.rb".
        #
        def source=(source)
          if source
            @source = ::File.expand_path(base.find_in_source_paths(source.to_s))
          end
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
        def invoke_with_options!(options, &block)
          if exists?
            if is_not_comparable?
              say_status :exist, :blue
            elsif identical?
              say_status :identical, :blue
            else
              force_or_skip_or_conflict(options[:force], options[:skip], &block)
            end
          else
            say_status :create, :green
            block.call unless pretend?
          end

          destination
        end

        # If force is true, run the action, otherwise check if it's not being
        # skipped. If both are false, show the file_collision menu, if the menu
        # returns true, force it, otherwise skip.
        #
        def force_or_skip_or_conflict(force, skip, &block)
          if force
            say_status :force, :yellow
            block.call unless pretend?
          elsif skip
            say_status :skip, :yellow
          else
            say_status :conflict, :red
            force_or_skip_or_conflict(force_on_collision?, true, &block)
          end
        end

        # Shows the file collision menu to the user and gets the result.
        #
        def force_on_collision?
          base.shell.file_collision(destination){ render }
        end

        # Shortcut to say_status shell method.
        #
        def say_status(status, color)
          base.shell.say_status status, relative_destination, color if config[:verbose]
        end

    end
  end
end
