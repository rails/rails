#!/usr/bin/env ruby

# This is a really simple session storage daemon, basically just a hash,
# which is enabled for DRb access.

require 'drb'

session_hash = Hash.new
session_hash.instance_eval { @mutex = Mutex.new }

class <<session_hash
  def []=(key, value)
    @mutex.synchronize do
      super(key, value)
    end
  end

  def [](key)
    @mutex.synchronize do
      super(key)
    end
  end

  def delete(key)
    @mutex.synchronize do
      super(key)
    end
  end
end

DRb.start_service('druby://127.0.0.1:9192', session_hash)
DRb.thread.join
