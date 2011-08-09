module ActionView #:nodoc:
  # = Action View PathSet
  class PathSet #:nodoc:
    include Enumerable

    attr_reader :paths

    def initialize(paths = [])
      @paths = paths
      typecast!
    end

    def initialize_copy(other)
      @paths = other.paths.dup
      self
    end

    def to_ary
      paths.dup
    end

    def +(array)
      PathSet.new(paths + array)
    end

    def include?(item)
      paths.include? item
    end

    def pop
      paths.pop
    end

    def size
      paths.size
    end

    def compact
      PathSet.new paths.compact
    end

    def each(&block)
      paths.each(&block)
    end

    %w(<< concat push insert unshift).each do |method|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{method}(*args)
          paths.#{method}(*args)
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
        paths.each do |resolver|
          templates = resolver.find_all(path, prefix, *args)
          return templates unless templates.empty?
        end
      end
      []
    end

    def exists?(path, prefixes, *args)
      find_all(path, prefixes, *args).any?
    end

  protected

    def typecast!
      paths.each_with_index do |path, i|
        path = path.to_s if path.is_a?(Pathname)
        next unless path.is_a?(String)
        paths[i] = OptimizedFileSystemResolver.new(path)
      end
    end
  end
end
