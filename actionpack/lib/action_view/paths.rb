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

    def find(path, prefix = nil, partial = false, details = {}, key = nil)
      template = find_all(path, prefix, partial, details, key).first
      raise MissingTemplate.new(self, "#{prefix}/#{path}", details, partial) unless template
      template
    end

    def find_all(*args)
      each do |resolver|
        templates = resolver.find_all(*args)
        return templates unless templates.empty?
      end
      []
    end

    def exists?(*args)
      find_all(*args).any?
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
