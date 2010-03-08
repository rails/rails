module ActionView #:nodoc:
  class PathSet < Array #:nodoc:
    %w(initialize << concat insert push unshift).each do |method|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{method}(*args)
          super
          typecast!
        end
      METHOD
    end

    def find(path, details = {}, prefix = nil, partial = false, key=nil)
      each do |resolver|
        if template = resolver.find(path, details, prefix, partial)
          return template
        end
      end
      
      raise ActionView::MissingTemplate.new(self, "#{prefix}/#{path}", details, partial)
    end
    
    def exists?(path, details = {}, prefix = nil, partial = false, key=nil)
      each do |resolver|
        if resolver.find(path, details, prefix, partial)
          return true
        end
      end
      false
    end

  protected

    def typecast!
      each_with_index do |path, i|
        next unless path.is_a?(String)
        self[i] = FileSystemResolver.new(path)
      end
    end
  end
end
