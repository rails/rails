module ActionView
  class TemplateHandler

    def self.line_offset
      0
    end

    def self.compilable?
      false
    end

    def initialize(view)
      @view = view
    end

    def render(template)
    end

    def compile(template)
    end

    def compilable?
      self.class.compilable?
    end

    def line_offset
      self.class.line_offset
    end

    # Called by CacheHelper#cache
    def cache_fragment(block, name = {}, options = nil)
    end
  end
end
