module Rails
  module Generators
    class ObserverGenerator < NamedBase #metagenerator
      hook_for :orm
    end
  end
end
