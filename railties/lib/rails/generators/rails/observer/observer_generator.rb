module Rails
  module Generators
    class ObserverGenerator < NamedBase # :nodoc:
      hook_for :orm, required: true
    end
  end
end
