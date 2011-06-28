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
      find_all(*args).first || raise(MissingTemplate.new(self, *args))
    end

    def find_all(path, prefixes = [], *args)
      prefixes = [prefixes] if String === prefixes
      prefixes.each do |prefix|
        each do |resolver|
          templates = resolver.find_all(path, prefix, *args)
          return templates unless templates.empty?
        end
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
        self[i] = OptimizedFileSystemResolver.new(path)
      end
    end
  end
end
