module ActionView #:nodoc:
  class PathSet < Array #:nodoc:
    def self.type_cast(obj)
      if obj.is_a?(String)
        Template::Path.new(obj)
      else
        obj
      end
    end

    def initialize(*args)
      super(*args).map! { |obj| self.class.type_cast(obj) }
    end

    def <<(obj)
      super(self.class.type_cast(obj))
    end

    def concat(array)
      super(array.map! { |obj| self.class.type_cast(obj) })
    end

    def insert(index, obj)
      super(index, self.class.type_cast(obj))
    end

    def push(*objs)
      super(*objs.map { |obj| self.class.type_cast(obj) })
    end

    def unshift(*objs)
      super(*objs.map { |obj| self.class.type_cast(obj) })
    end

    def find_template(template_path, format = nil)
      return template_path if template_path.respond_to?(:render)

      each do |load_path|
        if format && (template = load_path["#{template_path}.#{I18n.locale}.#{format}"])
          return template
        elsif format && (template = load_path["#{template_path}.#{format}"])
          return template
        elsif template = load_path["#{template_path}.#{I18n.locale}"]
          return template
        elsif template = load_path[template_path]
          return template
        # Try to find html version if the format is javascript
        elsif format == :js && template = load_path["#{template_path}.#{I18n.locale}.html"]
          return template
        elsif format == :js && template = load_path["#{template_path}.html"]
          return template
        end
      end

      if File.exist?(template_path)
        return Template.new(template_path, template_path[0] == 47 ? "" : ".")
      end

      raise MissingTemplate.new(self, template_path, format)
    end
  end
end
