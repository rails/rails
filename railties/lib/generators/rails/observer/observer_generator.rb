module Rails
  module Generators
    class ObserverGenerator < NamedBase
      hook_for :orm
    end
  end
end
