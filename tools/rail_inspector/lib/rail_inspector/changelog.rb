# frozen_string_literal: true

require "pathname"
require "strscan"

module RailInspector
  class Changelog
    class Offense
      attr_reader :line, :line_number, :range, :message

      def initialize(line, line_number, range, message)
        @line = line
        @line_number = line_number
        @range = range
        @message = message
      end
    end

    class Entry
      attr_reader :lines, :offenses

      def initialize(lines, starting_line)
        @lines = lines
        @starting_line = starting_line

        @offenses = []

        validate_authors
        validate_leading_whitespace
        validate_trailing_whitespace
      end

      private
        def header
          lines.first
        end

        def validate_authors
          return if no_changes?

          authors =
            lines.reverse.find { |line| line.match?(/^ *\*[^*\s].*[^*\s]\*$/) }

          return if authors

          add_offense(
            header,
            line_in_file(0),
            1..header.length,
            "CHANGELOG entry is missing authors."
          )
        end

        def validate_leading_whitespace
          unless header.match?(/\* {3}\S/)
            add_offense(
              header,
              line_in_file(0),
              1..4,
              "CHANGELOG header must start with '*' and 3 spaces"
            )
          end

          lines.each_with_index do |line, i|
            next if i == 0
            next if line.strip.empty?
            next if line.start_with?(" " * 4)

            add_offense(
              line,
              line_in_file(i),
              1..4,
              "CHANGELOG line must be indented 4 spaces"
            )
          end
        end

        def validate_trailing_whitespace
          lines.each_with_index do |line, i|
            next unless line.end_with?(" ", "\t")

            add_offense(
              line,
              line_in_file(i),
              (line.rstrip.length + 1)..line.length,
              "Trailing whitespace detected."
            )
          end
        end

      private
        def no_changes?
          lines.first == "*   No changes."
        end

        def add_offense(...)
          @offenses << Offense.new(...)
        end

        def line_in_file(line_in_entry)
          @starting_line + line_in_entry
        end
    end

    class Parser
      def self.call(file)
        new(file).parse
      end

      def self.to_proc
        method(:call).to_proc
      end

      def initialize(file)
        @buffer = StringScanner.new(file)
        @lines = []
        @current_line = 1

        @entries = []
      end

      def parse
        until @buffer.eos?
          if peek_release_header?
            pop_entry
            next parse_release_header
          end

          if peek_footer?
            pop_entry
            next parse_footer
          end

          pop_entry if peek_probably_header?

          parse_line
        end

        @entries
      end

      private
        def parse_line
          @current_line += 1
          @lines << @buffer.scan_until(/\n/)[0...-1]
        end

        FOOTER_TEXT = "Please check"

        RELEASE_HEADER = "## Rails"

        def peek_release_header?
          @buffer.peek(RELEASE_HEADER.length) == RELEASE_HEADER
        end

        def parse_release_header
          @buffer.scan(
            /#{RELEASE_HEADER} .*##\s*/o
          )
        end

        def parse_footer
          @buffer.scan(
            /#{FOOTER_TEXT} \[\d-\d-stable\]\(.*\) for previous changes\.\n/o
          )
        end

        def peek_probably_header?
          return false unless @buffer.peek(1) == "*"

          maybe_header = @buffer.check_until(/\n/).strip

          # If there are an odd number of *, then the line is almost certainly a
          # header since bolding requires pairs.
          return true unless maybe_header.count("*").even?

          !maybe_header.end_with?("*")
        end

        def peek_footer?
          @buffer.peek(FOOTER_TEXT.length) == FOOTER_TEXT
        end

        def pop_entry
          # Ensure we don't pop an entry if we only see newlines and the footer
          return unless @lines.any? { |line| line.match?(/\S/) }

          @entries << Changelog::Entry.new(@lines, @current_line - @lines.length)
          @lines = []
        end
    end

    class Formatter
      def initialize
        @changelog_count = 0
        @offense_count = 0
      end

      def to_proc
        method(:call).to_proc
      end

      def call(changelog)
        @changelog_count += 1

        changelog.offenses.each { |o| process_offense(changelog, o) }
      end

      def finish
        puts "#{@changelog_count} changelogs inspected, #{@offense_count} offense#{"s" unless @offense_count == 1} detected"
      end

      private
        def process_offense(file, offense)
          @offense_count += 1

          puts "#{file.path}:#{offense.line_number} #{offense.message}"
          puts offense.line
          puts ("^" * offense.range.count).rjust(offense.range.end)
        end
    end

    class Runner
      attr_reader :formatter, :rails_path

      def initialize(rails_path)
        @formatter = Formatter.new
        @rails_path = Pathname.new(rails_path)
      end

      def call
        invalid_changelogs =
          changelogs.reject do |changelog|
            output = changelog.valid? ? "." : "E"
            $stdout.write(output)

            changelog.valid?
          end

        puts "\n\n"
        puts "Offenses:\n\n" unless invalid_changelogs.empty?

        changelogs.each(&formatter)
        formatter.finish

        invalid_changelogs.empty?
      end

      private
        def changelogs
          changelog_paths.map { |path| Changelog.new(path, File.read(path)) }
        end

        def changelog_paths
          Dir[rails_path.join("*/CHANGELOG.md")]
        end
    end

    attr_reader :path, :content, :entries

    def initialize(path, content)
      @path = path
      @content = content
      @entries = parser.parse
    end

    def valid?
      offenses.empty?
    end

    def offenses
      @offenses ||= entries.flat_map(&:offenses)
    end

    private
      def parser
        @parser ||= Parser.new(content)
      end
  end
end
