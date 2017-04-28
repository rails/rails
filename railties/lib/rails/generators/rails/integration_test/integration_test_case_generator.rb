module Rails
  module Generators
    class IntegrationTestCaseGenerator < NamedBase # :nodoc:
      hook_for :integration_tool, as: :integration
    end
  end
end
