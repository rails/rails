# frozen_string_literal: true

require_relative "abstract_unit"

class ForkTrackerTest < ActiveSupport::TestCase
  def test_object_fork
    read, write = IO.pipe
    called = false

    handler = ActiveSupport::ForkTracker.after_fork do
      called = true
      write.write "forked"
    end

    assert_not respond_to?(:fork)
    pid = fork do
      read.close
      write.close
      exit!
    end

    write.close

    Process.waitpid(pid)
    assert_equal "forked", read.read
    read.close

    assert_not called
  ensure
    ActiveSupport::ForkTracker.unregister(handler)
  end

  def test_object_fork_without_block
    read, write = IO.pipe
    called = false

    handler = ActiveSupport::ForkTracker.after_fork do
      called = true
      write.write "forked"
    end

    if pid = fork
      write.close
      Process.waitpid(pid)
      assert_equal "forked", read.read
      read.close
      assert_not called
    else
      read.close
      write.close
      exit!
    end
  ensure
    ActiveSupport::ForkTracker.unregister(handler)
  end

  def test_process_fork
    read, write = IO.pipe
    called = false

    handler = ActiveSupport::ForkTracker.after_fork do
      called = true
      write.write "forked"
    end

    pid = Process.fork do
      read.close
      write.close
      exit!
    end

    write.close

    Process.waitpid(pid)
    assert_equal "forked", read.read
    read.close
    assert_not called
  ensure
    ActiveSupport::ForkTracker.unregister(handler)
  end

  def test_process_fork_without_block
    read, write = IO.pipe
    called = false

    handler = ActiveSupport::ForkTracker.after_fork do
      called = true
      write.write "forked"
    end

    if pid = Process.fork
      write.close
      Process.waitpid(pid)
      assert_equal "forked", read.read
      read.close
      assert_not called
    else
      read.close
      write.close
      exit!
    end
  ensure
    ActiveSupport::ForkTracker.unregister(handler)
  end

  def test_kernel_fork
    read, write = IO.pipe
    called = false

    handler = ActiveSupport::ForkTracker.after_fork do
      called = true
      write.write "forked"
    end

    pid = Kernel.fork do
      read.close
      write.close
      exit!
    end

    write.close

    Process.waitpid(pid)
    assert_equal "forked", read.read
    read.close
    assert_not called
  ensure
    ActiveSupport::ForkTracker.unregister(handler)
  end

  def test_kernel_fork_without_block
    read, write = IO.pipe
    called = false

    handler = ActiveSupport::ForkTracker.after_fork do
      called = true
      write.write "forked"
    end

    if pid = Kernel.fork
      write.close
      Process.waitpid(pid)
      assert_equal "forked", read.read
      read.close
      assert_not called
    else
      read.close
      write.close
      exit!
    end
  ensure
    ActiveSupport::ForkTracker.unregister(handler)
  end

  def test_basic_object_with_kernel_fork
    read, write = IO.pipe
    called = false

    handler = ActiveSupport::ForkTracker.after_fork do
      called = true
      write.write "forked"
    end

    klass = Class.new(BasicObject) do
      include ::Kernel
      def fark(&block)
        fork(&block)
      end
    end

    object = klass.new
    assert_not object.respond_to?(:fork)
    pid = object.fark do
      read.close
      write.close
      exit!
    end

    write.close

    Process.waitpid(pid)
    assert_equal "forked", read.read
    read.close

    assert_not called
  ensure
    ActiveSupport::ForkTracker.unregister(handler)
  end
end if Process.respond_to?(:fork)
