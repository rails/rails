# frozen_string_literal: true

# Holds the tasks it is given, then runs those waiting at the time newest first.
# This is one of the orders in which a pool of threads can run tasks that were
# posted one after the other.
class OutOfOrderExecutor
  def initialize
    @tasks = []
  end

  def post(task = nil, &block)
    @tasks << (task || block)
    true
  end

  def run_all
    until @tasks.empty?
      @tasks.slice!(0..).reverse_each(&:call)
    end
  end
end
