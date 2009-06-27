module Rails
  module Generators
    class ObserverGenerator < NamedBase
      hook_for :orm, :test_framework
    end
  end
end
