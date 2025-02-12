# frozen_string_literal: true

require "rails/code_statistics_calculator"
require "active_support/core_ext/enumerable"

module Rails
  class CodeStatistics
    DIRECTORIES = [
      %w(Controllers        app/controllers),
      %w(Helpers            app/helpers),
      %w(Jobs               app/jobs),
      %w(Models             app/models),
      %w(Mailers            app/mailers),
      %w(Mailboxes          app/mailboxes),
      %w(Channels           app/channels),
      %w(Views              app/views),
      %w(JavaScripts        app/assets/javascripts),
      %w(Stylesheets        app/assets/stylesheets),
      %w(JavaScript         app/javascript),
      %w(Libraries          lib/),
      %w(APIs               app/apis),
      %w(Controller\ tests  test/controllers),
      %w(Helper\ tests      test/helpers),
      %w(Job\ tests         test/jobs),
      %w(Model\ tests       test/models),
      %w(Mailer\ tests      test/mailers),
      %w(Mailbox\ tests     test/mailboxes),
      %w(Channel\ tests     test/channels),
      %w(Integration\ tests test/integration),
      %w(System\ tests      test/system),
    ]

    TEST_TYPES = ["Controller tests",
                  "Helper tests",
                  "Model tests",
                  "Mailer tests",
                  "Mailbox tests",
                  "Channel tests",
                  "Job tests",
                  "Integration tests",
                  "System tests"]

    HEADERS = { lines: " Lines", code_lines: "   LOC", classes: "Classes", methods: "Methods" }

    class_attribute :directories, default: DIRECTORIES
    class_attribute :test_types, default: TEST_TYPES

    # Add directories to the output of the <tt>bin/rails stats</tt> command.
    #
    #   Rails::CodeStatistics.register_directory("My Directory", "path/to/dir")
    #
    # For directories that contain test code, set the <tt>test_directory</tt> argument to true.
    #
    #   Rails::CodeStatistics.register_directory("Model specs", "spec/models", test_directory: true)
    def self.register_directory(label, path, test_directory: false)
      self.directories << [label, path]
      self.test_types << label if test_directory
    end

    def initialize(*pairs)
      @pairs      = pairs
      @statistics = calculate_statistics
      @total      = calculate_total if pairs.length > 1
    end

    def to_s
      print_header
      @pairs.each { |pair| print_line(pair.first, @statistics[pair.first]) }
      print_splitter

      if @total
        print_line("Total", @total)
        print_splitter
      end

      print_code_test_stats
    end

    private
      def calculate_statistics
        Hash[@pairs.map { |pair| [pair.first, calculate_directory_statistics(pair.last)] }]
      end

      def calculate_directory_statistics(directory, pattern = /^(?!\.).*?\.(rb|js|ts|css|scss|coffee|rake|erb)$/)
        stats = Rails::CodeStatisticsCalculator.new

        Dir.foreach(directory) do |file_name|
          path = "#{directory}/#{file_name}"

          if File.directory?(path) && !file_name.start_with?(".")
            stats.add(calculate_directory_statistics(path, pattern))
          elsif file_name&.match?(pattern)
            stats.add_by_file_path(path)
          end
        end

        stats
      end

      def calculate_total
        @statistics.each_with_object(Rails::CodeStatisticsCalculator.new) do |pair, total|
          total.add(pair.last)
        end
      end

      def calculate_code
        code_loc = 0
        @statistics.each { |k, v| code_loc += v.code_lines unless test_types.include? k }
        code_loc
      end

      def calculate_tests
        test_loc = 0
        @statistics.each { |k, v| test_loc += v.code_lines if test_types.include? k }
        test_loc
      end

      def width_for(label)
        [@statistics.values.sum { |s| s.public_send(label) }.to_s.size, HEADERS[label].length].max
      end

      def print_header
        print_splitter
        print "| Name                "
        HEADERS.each do |k, v|
          print " | #{v.rjust(width_for(k))}"
        end
        puts " | M/C | LOC/M |"
        print_splitter
      end

      def print_splitter
        print "+----------------------"
        HEADERS.each_key do |k|
          print "+#{'-' * (width_for(k) + 2)}"
        end
        puts "+-----+-------+"
      end

      def print_line(name, statistics)
        m_over_c   = (statistics.methods / statistics.classes) rescue 0
        loc_over_m = (statistics.code_lines / statistics.methods) - 2 rescue 0

        print "| #{name.ljust(20)} "
        HEADERS.each_key do |k|
          print "| #{statistics.send(k).to_s.rjust(width_for(k))} "
        end
        puts "| #{m_over_c.to_s.rjust(3)} | #{loc_over_m.to_s.rjust(5)} |"
      end

      def print_code_test_stats
        code  = calculate_code
        tests = calculate_tests

        puts "  Code LOC: #{code}     Test LOC: #{tests}     Code to Test Ratio: 1:#{sprintf("%.1f", tests.to_f / code)}"
        puts ""
      end
  end
end
