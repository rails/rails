module Rails
  module Generators
    class IntegrationTestGenerator < NamedBase
      hook_for :integration_tool, :as => :integration
    end
  end
end
