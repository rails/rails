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

    # Called by CacheHelper#cache
    def cache_fragment(block, name = {}, options = nil)
    end
  end
end
