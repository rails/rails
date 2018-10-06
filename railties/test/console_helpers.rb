# frozen_string_literal: true

begin
  require "pty"
rescue LoadError
end

module ConsoleHelpers
  def assert_output(expected, io, timeout = 10)
    timeout = Time.now + timeout

    output = +""
    until output.include?(expected) || Time.now > timeout
      if IO.select([io], [], [], 0.1)
        output << io.read(1)
      end
    end

    assert_includes output, expected, "#{expected.inspect} expected, but got:\n\n#{output}"
  end

  def available_pty?
    defined?(PTY) && PTY.respond_to?(:open)
  end
end
