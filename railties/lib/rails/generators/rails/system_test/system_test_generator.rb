module Rails
  module Generators
    class SystemTestGenerator < NamedBase # :nodoc:
      hook_for :system_tool, as: :system
    end
  end
end
