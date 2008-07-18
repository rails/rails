# Legacy TemplateHandler stub

module ActionView
  module TemplateHandlers
    module Compilable
    end
  end

  class TemplateHandler
    def self.call(template)
      new.compile(template)
    end
  end
end
