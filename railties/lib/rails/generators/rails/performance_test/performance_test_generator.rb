module Rails
  module Generators
    class PerformanceTestGenerator < NamedBase # :nodoc:
      hook_for :performance_tool, as: :performance
    end
  end
end
