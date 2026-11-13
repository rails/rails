# frozen_string_literal: true

begin
  require "pty"
rescue LoadError
end

module ConsoleHelpers
  def assert_output(expected, io, timeout = 10)
    timeout = Time.now + timeout

    output = +""
    until output[expected] || Time.now > timeout
      if IO.select([io], [], [], 0.1)
        output << io.read(1)
      end
    end

    assert output[expected], "#{expected.inspect} expected, but got:\n\n#{output}"
  end

  def run_in_terminal(*command, prompt:, input:, env: {}, chdir:, timeout: 10)
    require "expect"

    output = +""

    PTY.spawn(env, *command, chdir: chdir) do |reader, writer, pid|
      input.each do |line|
        match = reader.expect(prompt, timeout)
        assert match, "#{prompt.inspect} expected, but got:\n\n#{output}"
        output << match.first
        writer.puts line
      end

      deadline = Time.now + timeout
      begin
        while (remaining = deadline - Time.now) > 0 && IO.select([reader], nil, nil, remaining)
          output << reader.readpartial(1024)
        end
      rescue Errno::EIO, EOFError
      end
    ensure
      if pid
        begin
          Process.kill("TERM", pid)
        rescue Errno::ESRCH
        end
        Process.wait(pid)
      end
    end

    output.gsub("\r\n", "\n")
  end
end

def available_pty?
  defined?(PTY) && PTY.respond_to?(:open)
end
