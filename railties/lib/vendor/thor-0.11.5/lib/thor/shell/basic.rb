require 'tempfile'

class Thor
  module Shell
    class Basic
      attr_accessor :base, :padding

      # Initialize base and padding to nil.
      #
      def initialize #:nodoc:
        @base, @padding = nil, 0
      end

      # Sets the output padding, not allowing less than zero values.
      #
      def padding=(value)
        @padding = [0, value].max
      end

      # Ask something to the user and receives a response.
      #
      # ==== Example
      # ask("What is your name?")
      #
      def ask(statement, color=nil)
        say("#{statement} ", color)
        $stdin.gets.strip
      end

      # Say (print) something to the user. If the sentence ends with a whitespace
      # or tab character, a new line is not appended (print + flush). Otherwise
      # are passed straight to puts (behavior got from Highline).
      #
      # ==== Example
      # say("I know you knew that.")
      #
      def say(message="", color=nil, force_new_line=false)
        message  = message.to_s
        new_line = force_new_line || !(message[-1, 1] == " " || message[-1, 1] == "\t")
        message  = set_color(message, color) if color

        if new_line
          $stdout.puts(message)
        else
          $stdout.print(message)
          $stdout.flush
        end
      end

      # Say a status with the given color and appends the message. Since this
      # method is used frequently by actions, it allows nil or false to be given
      # in log_status, avoiding the message from being shown. If a Symbol is
      # given in log_status, it's used as the color.
      #
      def say_status(status, message, log_status=true)
        return if quiet? || log_status == false
        spaces = "  " * (padding + 1)
        color  = log_status.is_a?(Symbol) ? log_status : :green

        status = status.to_s.rjust(12)
        status = set_color status, color, true if color
        say "#{status}#{spaces}#{message}", nil, true
      end

      # Make a question the to user and returns true if the user replies "y" or
      # "yes".
      #
      def yes?(statement, color=nil)
        ask(statement, color) =~ is?(:yes)
      end

      # Make a question the to user and returns true if the user replies "n" or
      # "no".
      #
      def no?(statement, color=nil)
        !yes?(statement, color)
      end

      # Prints a list of items.
      #
      # ==== Parameters
      # list<Array[String, String, ...]>
      #
      # ==== Options
      # mode:: Can be :rows or :inline. Defaults to :rows.
      # ident:: Ident each item with the value given.
      #
      def print_list(list, options={})
        return if list.empty?

        ident   = " " * (options[:ident] || 0)
        content = case options[:mode]
          when :inline
            last = list.pop
            "#{list.join(", ")}, and #{last}"
          else # rows
            ident + list.join("\n#{ident}")
        end

        $stdout.puts content
      end

      # Prints a table.
      #
      # ==== Parameters
      # Array[Array[String, String, ...]]
      #
      # ==== Options
      # ident<Integer>:: Ident the first column by ident value.
      #
      def print_table(table, options={})
        return if table.empty?

        formats = []
        0.upto(table.first.length - 2) do |i|
          maxima = table.max{ |a,b| a[i].size <=> b[i].size }[i].size
          formats << "%-#{maxima + 2}s"
        end

        formats[0] = formats[0].insert(0, " " * options[:ident]) if options[:ident]
        formats << "%s"

        table.each do |row|
          row.each_with_index do |column, i|
            $stdout.print formats[i] % column.to_s
          end
          $stdout.puts
        end
      end

      # Deals with file collision and returns true if the file should be
      # overwriten and false otherwise. If a block is given, it uses the block
      # response as the content for the diff.
      #
      # ==== Parameters
      # destination<String>:: the destination file to solve conflicts
      # block<Proc>:: an optional block that returns the value to be used in diff
      #
      def file_collision(destination)
        return true if @always_force
        options = block_given? ? "[Ynaqdh]" : "[Ynaqh]"

        while true
          answer = ask %[Overwrite #{destination}? (enter "h" for help) #{options}]

          case answer
            when is?(:yes), is?(:force)
              return true
            when is?(:no), is?(:skip)
              return false
            when is?(:always)
              return @always_force = true
            when is?(:quit)
              say 'Aborting...'
              raise SystemExit
            when is?(:diff)
              show_diff(destination, yield) if block_given?
              say 'Retrying...'
            else
              say file_collision_help
          end
        end
      end

      # Called if something goes wrong during the execution. This is used by Thor
      # internally and should not be used inside your scripts. If someone went
      # wrong, you can always raise an exception. If you raise a Thor::Error, it
      # will be rescued and wrapped in the method below.
      #
      def error(statement)
        $stderr.puts statement
      end

      # Apply color to the given string with optional bold. Disabled in the
      # Thor::Shell::Basic class.
      #
      def set_color(string, color, bold=false) #:nodoc:
        string
      end

      protected

        def is?(value) #:nodoc:
          value = value.to_s

          if value.size == 1
            /\A#{value}\z/i
          else
            /\A(#{value}|#{value[0,1]})\z/i
          end
        end

        def file_collision_help #:nodoc:
<<HELP
Y - yes, overwrite
n - no, do not overwrite
a - all, overwrite this and all others
q - quit, abort
d - diff, show the differences between the old and the new
h - help, show this help
HELP
        end

        def show_diff(destination, content) #:nodoc:
          diff_cmd = ENV['THOR_DIFF'] || ENV['RAILS_DIFF'] || 'diff -u'

          Tempfile.open(File.basename(destination), File.dirname(destination)) do |temp|
            temp.write content
            temp.rewind
            system %(#{diff_cmd} "#{destination}" "#{temp.path}")
          end
        end

        def quiet? #:nodoc:
          base && base.options[:quiet]
        end

    end
  end
end
