module Rails
  module Generators
    class PerformanceTestGenerator < NamedBase
      hook_for :performance_tool, :as => :performance
    end
  end
end
