module Rails
  module Generators
    class ObserverGenerator < NamedBase
      invoke_for :orm, :test_framework
    end
  end
end
