module ActionView #:nodoc:
  # = Action View PathSet
  class PathSet < Array #:nodoc:
    %w(initialize << concat insert push unshift).each do |method|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{method}(*args)
          super
          typecast!
        end
      METHOD
    end

    def find(*args)
      if template = find_first(*args)
        template
      else
        raise MissingTemplate.new(self, *args)
      end
    end

    def find_all(path, prefixes = [], *args)
      prefixes.each do |prefix|
        templates = []
        each do |resolver|
          templates.concat resolver.find_all(path, prefix, *args)
        end
        return templates unless templates.empty?
      end
      []
    end

    def find_first(path, prefixes = [], *args)
      prefixes.each do |prefix|
        each do |resolver|
          template = resolver.find_all(path, prefix, *args).first
          return template if template
        end
      end
      nil
    end

    def exists?(*args)
      !!find_first(*args)
    end

  protected

    def typecast!
      each_with_index do |path, i|
        path = path.to_s if path.is_a?(Pathname)
        next unless path.is_a?(String)
        self[i] = FileSystemResolver.new(path)
      end
    end
  end
end
