module ActionView #:nodoc:
  # = Action View PathSet
  class PathSet #:nodoc:
    include Enumerable

    attr_reader :paths

    delegate :[], :include?, :pop, :size, :each, to: :paths

    def initialize(paths = [])
      @paths = typecast paths
    end

    def initialize_copy(other)
      @paths = other.paths.dup
      self
    end

    def to_ary
      paths.dup
    end

    def compact
      PathSet.new paths.compact
    end

    def +(array)
      PathSet.new(paths + array)
    end

    %w(<< concat push insert unshift).each do |method|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{method}(*args)
          paths.#{method}(*typecast(args))
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

    private

    def typecast(paths)
      paths.map do |path|
        case path
        when Pathname, String
          OptimizedFileSystemResolver.new path.to_s
        else
          path
        end
      end
    end
  end
end
