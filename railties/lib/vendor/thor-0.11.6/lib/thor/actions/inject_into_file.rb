require 'thor/actions/empty_directory'

class Thor
  module Actions

    # Injects the given content into a file. Different from gsub_file, this
    # method is reversible.
    #
    # ==== Parameters
    # destination<String>:: Relative path to the destination root
    # data<String>:: Data to add to the file. Can be given as a block.
    # config<Hash>:: give :verbose => false to not log the status and the flag
    #                for injection (:after or :before).
    # 
    # ==== Examples
    #
    #   inject_into_file "config/environment.rb", "config.gem :thor", :after => "Rails::Initializer.run do |config|\n"
    #
    #   inject_into_file "config/environment.rb", :after => "Rails::Initializer.run do |config|\n" do
    #     gems = ask "Which gems would you like to add?"
    #     gems.split(" ").map{ |gem| "  config.gem :#{gem}" }.join("\n")
    #   end
    #
    def inject_into_file(destination, *args, &block)
      if block_given?
        data, config = block, args.shift
      else
        data, config = args.shift, args.shift
      end
      action InjectIntoFile.new(self, destination, data, config)
    end

    class InjectIntoFile < EmptyDirectory #:nodoc:
      attr_reader :replacement, :flag, :behavior

      def initialize(base, destination, data, config)
        super(base, destination, { :verbose => true }.merge(config))

        @behavior, @flag = if @config.key?(:after)
          [:after, @config.delete(:after)]
        else
          [:before, @config.delete(:before)]
        end

        @replacement = data.is_a?(Proc) ? data.call : data
        @flag = Regexp.escape(@flag) unless @flag.is_a?(Regexp)
      end

      def invoke!
        say_status :invoke

        content = if @behavior == :after
          '\0' + replacement
        else
          replacement + '\0'
        end

        replace!(/#{flag}/, content)
      end

      def revoke!
        say_status :revoke

        regexp = if @behavior == :after
          content = '\1\2'
          /(#{flag})(.*)(#{Regexp.escape(replacement)})/m
        else
          content = '\2\3'
          /(#{Regexp.escape(replacement)})(.*)(#{flag})/m
        end

        replace!(regexp, content)
      end

      protected

        def say_status(behavior)
          status = if flag == /\A/
            behavior == :invoke ? :prepend : :unprepend
          elsif flag == /\z/
            behavior == :invoke ? :append : :unappend
          else
            behavior == :invoke ? :inject : :deinject
          end

          super(status, config[:verbose])
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
