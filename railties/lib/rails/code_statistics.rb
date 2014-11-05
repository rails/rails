require 'rails/code_statistics_calculator'

class CodeStatistics #:nodoc:

  TEST_TYPES = ['Controller tests',
                'Helper tests',
                'Model tests',
                'Mailer tests',
                'Job tests',
                'Integration tests',
                'Functional tests (old)',
                'Unit tests (old)']

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
      Hash[@pairs.map{|pair| [pair.first, calculate_directory_statistics(pair.last)]}]
    end

    def calculate_directory_statistics(directory, pattern = /.*\.(rb|js|coffee)$/)
      stats = CodeStatisticsCalculator.new

      Dir.foreach(directory) do |file_name|
        path = "#{directory}/#{file_name}"

        if File.directory?(path) && (/^\./ !~ file_name)
          stats.add(calculate_directory_statistics(path, pattern))
        end

        next unless file_name =~ pattern

        stats.add_by_file_path(path)
      end

      stats
    end

    def calculate_total
      @statistics.each_with_object(CodeStatisticsCalculator.new) do |pair, total|
        total.add(pair.last)
      end
    end

    def calculate_code
      code_loc = 0
      @statistics.each { |k, v| code_loc += v.code_lines unless TEST_TYPES.include? k }
      code_loc
    end

    def calculate_tests
      test_loc = 0
      @statistics.each { |k, v| test_loc += v.code_lines if TEST_TYPES.include? k }
      test_loc
    end

    def print_header
      print_splitter
      puts "| Name                 | Lines |   LOC | Classes | Methods | M/C | LOC/M |"
      print_splitter
    end

    def print_splitter
      puts "+----------------------+-------+-------+---------+---------+-----+-------+"
    end

    def print_line(name, statistics)
      m_over_c   = (statistics.methods / statistics.classes) rescue m_over_c = 0
      loc_over_m = (statistics.code_lines / statistics.methods) - 2 rescue loc_over_m = 0

      puts "| #{name.ljust(20)} " \
           "| #{statistics.lines.to_s.rjust(5)} " \
           "| #{statistics.code_lines.to_s.rjust(5)} " \
           "| #{statistics.classes.to_s.rjust(7)} " \
           "| #{statistics.methods.to_s.rjust(7)} " \
           "| #{m_over_c.to_s.rjust(3)} " \
           "| #{loc_over_m.to_s.rjust(5)} |"
    end

    def print_code_test_stats
      code  = calculate_code
      tests = calculate_tests

      puts "  Code LOC: #{code}     Test LOC: #{tests}     Code to Test Ratio: 1:#{sprintf("%.1f", tests.to_f/code)}"
      puts ""
    end
end
