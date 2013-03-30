require 'rake/testtask'

module Rails
  class TestTask < Rake::TestTask # :nodoc: all
    def initialize(name = :test)
      super
      @libs << "test" # lib *and* test seem like a better default
    end

    def define
      task @name do
        if ENV['TESTOPTS']
          ARGV.replace Shellwords.split ENV['TESTOPTS']
        end
        libs = @libs - $LOAD_PATH
        $LOAD_PATH.unshift(*libs)
        file_list.each { |fl|
          FileList[fl].to_a.each { |f| require File.expand_path f }
        }
      end
    end
  end

  # Silence the default description to cut down on `rake -T` noise.
  class SubTestTask < Rake::TestTask # :nodoc:
    def desc(string)
      # Ignore the description.
    end
  end
end
