module Rails
  module Generators
    class ObserverGenerator < NamedBase #metagenerator
      hook_for :orm, :required => true
    end
  end
end
