# Legacy TemplateHandler stub

module ActionView
  class TemplateHandler
    def self.call(template)
      new.compile(template)
    end
  end
end
