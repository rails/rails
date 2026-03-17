# frozen_string_literal: true

require "tmpdir"

module ActiveSupport
  class ContinuousIntegration
    class Group # :nodoc:
      class TaskCollector
        attr_reader :tasks

        def initialize(&block)
          @tasks = []
          instance_eval(&block)
        end

        def step(title, *command)
          @tasks << [:step, title, command]
        end

        def group(name, **options, &block)
          raise ArgumentError, "Sub-groups cannot be parallelized. Remove the `parallel:` option from the #{name.inspect} group." if options.key?(:parallel)
          @tasks << [:group, name, block]
        end
      end

      def initialize(ci, name, parallel:, &block)
        @ci = ci
        @name = name
        @parallel = parallel
        @tasks = TaskCollector.new(&block).tasks
        @start_time = Time.now.to_f
        @mutex = Mutex.new
        @running = {}
        @progress_visible = false
        @log_files = []
      end

      def run
        previous_trap = Signal.trap("INT") { abort @ci.colorize("\n❌ #{@running.keys.join(', ')} interrupted", :error) }

        queue = Queue.new
        @tasks.each { |task| queue << task }

        with_progress do
          @parallel.times.map do
            Thread.new do
              while (task = dequeue(queue))
                break if @ci.failing_fast?
                execute_task(*task)
              end
            end
          end.each(&:join)
        end
      ensure
        Signal.trap("INT", previous_trap || "-")
        @log_files.each { |path| File.delete(path) if File.exist?(path) }
      end

      private
        def with_progress
          stop = false
          thread = Thread.new do
            until stop
              @mutex.synchronize { refresh_progress }
              sleep 0.1
            end
          end

          yield

          stop = true
          thread.join
        end

        def execute_task(type, title, payload)
          case type
          when :step  then execute_step(title, payload)
          when :group then execute_group(title, payload)
          end
        end

        def execute_step(title, command)
          @mutex.synchronize { @running[title] = Time.now.to_f }
          success, log_path = capture_output(command)
          @mutex.synchronize do
            started = @running.delete(title)
            clear_progress

            @ci.report_step(title, command) do
              replay_and_cleanup(log_path)
              [success, Time.now.to_f - started]
            end

            refresh_progress
          end
          success
        end

        def execute_group(name, block)
          all_success = true
          TaskCollector.new(&block).tasks.each do |type, title, payload|
            unless execute_task(type, title, payload)
              all_success = false
              break if @ci.fail_fast?
            end
          end

          all_success
        end

        def capture_output(command)
          log_path = Dir::Tmpname.create(["ci-", ".log"]) { }
          @mutex.synchronize { @log_files << log_path }

          success = spawn_process(command) do |output|
            File.open(log_path, "w") do |f|
              loop { f.write(output.readpartial(8192)) }
            rescue EOFError, Errno::EIO
              # Expected when process exits
            end
          end

          [success, log_path]
        rescue SystemCallError => e
          File.write(log_path, "#{e.message}: #{command.join(" ")}\n")
          [false, log_path]
        end

        def spawn_process(command, &block)
          # Prefer PTY if available to retain output colors
          if pty_available?
            spawn_via_pty(command, &block)
          else
            spawn_via_open3(command, &block)
          end
        end

        def pty_available?
          require "pty"
          true
        rescue LoadError
          false
        end

        def spawn_via_pty(command)
          output, input, pid = PTY.spawn(*command)
          input.close
          yield output
          Process.waitpid2(pid).last.success?
        rescue PTY::ChildExited => e
          e.status.success?
        end

        def spawn_via_open3(command)
          require "open3"
          Open3.popen2e(*command) do |input, output, wait_thr|
            input.close
            yield output
            wait_thr.value.success?
          end
        end

        def replay_and_cleanup(log_path)
          File.open(log_path, "r") do |f|
            while (chunk = f.read(8192))
              print chunk
            end
          end
          File.delete(log_path)
        end

        def refresh_progress
          if @running.any?
            print "\n\n" unless @progress_visible
            elapsed = format_elapsed_brief(Time.now.to_f - @start_time)
            print "\r\e[K#{@ci.colorize("#{@name} (#{elapsed}) - #{@running.keys.join(' | ')}...", :progress)}"
            @progress_visible = true
            $stdout.flush
          end
        end

        def clear_progress
          return unless @progress_visible
          print "\r\e[2A\e[J"
          @progress_visible = false
        end

        def format_elapsed_brief(seconds)
          min, sec = seconds.divmod(60)
          "#{"#{min.to_i}m" if min > 0}#{sec.to_i}s"
        end

        def dequeue(queue)
          queue.pop(true)
        rescue ThreadError
          nil
        end
    end
  end
end
