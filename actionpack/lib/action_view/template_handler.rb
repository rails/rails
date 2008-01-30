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

    def render(template, local_assigns)
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

    # This method reads a template file.
    def read_template_file(template_path, extension)
      File.read(template_path)
    end
  end
end
