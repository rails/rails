module Rails
  module Generators
    class IntegrationTestGenerator < NamedBase # :nodoc:
      hook_for :integration_tool, as: :integration
    end
  end
end
