# Bug fix for using Ruby 1.8.2 and Rake together to run tests.
require 'test/unit'

module Test
  module Unit
    module Collector
      class Dir
        def collect_file(name, suites, already_gathered)
          dir = File.dirname(File.expand_path(name))
          $:.unshift(dir) unless $:.first == dir
          if(@req)
            @req.require(name)
          else
            require(name)
          end
          find_test_cases(already_gathered).each{|t| add_suite(suites, t.suite)}
        rescue LoadError, SystemExit
        ensure
          $:.delete_at $:.rindex(dir)
        end
      end
    end
  end
end
