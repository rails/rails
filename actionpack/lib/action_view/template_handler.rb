module ActionView
  class TemplateHandler
    def self.line_offset
      0
    end

    def initialize(view)
      @view = view
    end

    def render(template, local_assigns)
    end

    def compile(template)
    end
  end
end
