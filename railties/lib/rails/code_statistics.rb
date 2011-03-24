class CodeStatistics #:nodoc:

  TEST_TYPES = %w(Units Functionals Unit\ tests Functional\ tests Integration\ tests)

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

    def calculate_directory_statistics(directory, pattern = /.*\.rb$/)
      stats = { "lines" => 0, "codelines" => 0, "classes" => 0, "methods" => 0 }

      Dir.foreach(directory) do |file_name|
        if File.stat(directory + "/" + file_name).directory? and (/^\./ !~ file_name)
          newstats = calculate_directory_statistics(directory + "/" + file_name, pattern)
          stats.each { |k, v| stats[k] += newstats[k] }
        end

        next unless file_name =~ pattern

        f = File.open(directory + "/" + file_name)

        while line = f.gets
          stats["lines"]     += 1
          stats["classes"]   += 1 if line =~ /class [A-Z]/
          stats["methods"]   += 1 if line =~ /def [a-z]/
          stats["codelines"] += 1 unless line =~ /^\s*$/ || line =~ /^\s*#/
        end
      end

      stats
    end

    def calculate_total
      total = { "lines" => 0, "codelines" => 0, "classes" => 0, "methods" => 0 }
      @statistics.each_value { |pair| pair.each { |k, v| total[k] += v } }
      total
    end

    def calculate_code
      code_loc = 0
      @statistics.each { |k, v| code_loc += v['codelines'] unless TEST_TYPES.include? k }
      code_loc
    end

    def calculate_tests
      test_loc = 0
      @statistics.each { |k, v| test_loc += v['codelines'] if TEST_TYPES.include? k }
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
      m_over_c   = (statistics["methods"] / statistics["classes"])   rescue m_over_c = 0
      loc_over_m = (statistics["codelines"] / statistics["methods"]) - 2 rescue loc_over_m = 0

      start = if TEST_TYPES.include? name
        "| #{name.ljust(20)} "
      else
        "| #{name.ljust(20)} "
      end

      puts start +
           "| #{statistics["lines"].to_s.rjust(5)} " +
           "| #{statistics["codelines"].to_s.rjust(5)} " +
           "| #{statistics["classes"].to_s.rjust(7)} " +
           "| #{statistics["methods"].to_s.rjust(7)} " +
           "| #{m_over_c.to_s.rjust(3)} " +
           "| #{loc_over_m.to_s.rjust(5)} |"
    end

    def print_code_test_stats
      code  = calculate_code
      tests = calculate_tests

      puts "  Code LOC: #{code}     Test LOC: #{tests}     Code to Test Ratio: 1:#{sprintf("%.1f", tests.to_f/code)}"
      puts ""
    end
  end
