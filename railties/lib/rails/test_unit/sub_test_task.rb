require 'rake/testtask'

module Rails
  class TestTask < Rake::TestTask # :nodoc: all
    class TestInfo
      def initialize(tasks)
        @tasks = tasks
      end

      def files
        @tasks.map { |task|
          [task, translate(task)].find { |file| test_file?(file) }
        }.compact
      end

      def translate(file)
        if file =~ /^app\/(.*)$/
          "test/#{$1.sub(/\.rb$/, '')}_test.rb"
        else
          "test/#{file}_test.rb"
        end
      end

      def tasks
        @tasks - test_file_tasks - opt_names
      end

      def opts
        opts = opt_names
        if opts.any?
          "-n #{opts.join ' '}"
        end
      end

      private

      def test_file_tasks
        @tasks.find_all { |task|
          [task, translate(task)].any? { |file| test_file?(file) }
        }
      end

      def test_file?(file)
        file =~ /^test/ && File.file?(file) && !File.directory?(file)
      end

      def opt_names
        (@tasks - test_file_tasks).reject { |t| task_defined? t }
      end

      def task_defined?(task)
        Rake::Task.task_defined? task
      end
    end

    def self.test_info(tasks)
      TestInfo.new tasks
    end

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
