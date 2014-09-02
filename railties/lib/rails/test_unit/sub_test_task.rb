require 'rake/testtask'

module Rails
  class TestTask < Rake::TestTask # :nodoc: all
    # A utility class which is used primarily in "rails/test_unit/testing.rake"
    # to help define rake tasks corresponding to <tt>rake test</tt>.
    #
    # This class takes a TestInfo class and defines the appropriate rake task
    # based on the information, then invokes it.
    class TestCreator # :nodoc:
      def initialize(info)
        @info = info
      end

      def invoke_rake_task
        if @info.files.any?
          create_and_run_single_test
          reset_application_tasks
        else
          Rake::Task[ENV['TEST'] ? 'test:single' : 'test:run'].invoke
        end
      end

      private

        def create_and_run_single_test
          Rails::TestTask.new('test:single') { |t|
            t.test_files = @info.files
          }
          ENV['TESTOPTS'] ||= @info.opts
          Rake::Task['test:single'].invoke
        end

        def reset_application_tasks
          Rake.application.top_level_tasks.replace @info.tasks
        end
    end

    # This is a utility class used by the <tt>TestTask::TestCreator</tt> class.
    # This class takes a set of test tasks and checks to see if they correspond
    # to test files (or can be transformed into test files). Calling <tt>files</tt>
    # provides the set of test files and is used when initializing tests after
    # a call to <tt>rake test</tt>.
    class TestInfo # :nodoc:
      def initialize(tasks)
        @tasks = tasks
        @files = nil
      end

      def files
        @files ||= @tasks.map { |task|
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

    def self.test_creator(tasks)
      info = TestInfo.new(tasks)
      TestCreator.new(info)
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
