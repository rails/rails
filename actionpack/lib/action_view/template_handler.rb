module ActionView
  class TemplateHandler
    def self.compilable?
      false
    end

    def initialize(view)
      @view = view
    end

    def render(template, local_assigns = {})
    end

    def compile(template)
    end

    def compilable?
      self.class.compilable?
    end
  end
end
