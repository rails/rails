module ActionView #:nodoc:
  class PathSet < Array #:nodoc:
    def self.type_cast(obj)
      if obj.is_a?(String)
        cache = !defined?(Rails) || !Rails.respond_to?(:configuration) || Rails.configuration.cache_classes
        FileSystemResolverWithFallback.new(obj, :cache => cache)
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

    def find(path, details = {}, prefix = nil, partial = false)
      # template_path = path.sub(/^\//, '')
      template_path = path

      each do |load_path|
        if template = load_path.find(template_path, details, prefix, partial)
          return template
        end
      end
      
      # TODO: Have a fallback absolute path?
      extension = details[:formats] || []
      raise ActionView::MissingTemplate.new(self, "#{prefix}/#{path} - #{details.inspect} - partial: #{!!partial}")
    end
    
    def exists?(path, extension = nil, prefix = nil, partial = false)
      template_path = path.sub(/^\//, '')

      each do |load_path|
        return true if template = load_path.find(template_path, extension, prefix, partial)
      end      
      false
    end

    def find_template(original_template_path, format = nil, html_fallback = true)
      return original_template_path if original_template_path.respond_to?(:render)
      template_path = original_template_path.sub(/^\//, '')

      each do |load_path|
        if template = load_path.find(template_path, format)
          return template
        # Try to find html version if the format is javascript
        elsif format == :js && html_fallback && template = load_path["#{template_path}.#{I18n.locale}.html"]
          return template
        elsif format == :js && html_fallback && template = load_path["#{template_path}.html"]
          return template
        end
      end

      return Template.new(original_template_path, original_template_path.to_s =~ /\A\// ? "" : ".") if File.file?(original_template_path)

      raise MissingTemplate.new(self, original_template_path, format)
    end
  end
end
