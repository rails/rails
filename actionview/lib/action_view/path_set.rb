module ActionView #:nodoc:
  # = Action View PathSet
  #
  # This class is used to store and access paths in Action View. A number of
  # operations are defined so that you can search among the paths in this
  # set and also perform operations on other +PathSet+ objects.
  #
  # A +LookupContext+ will use a +PathSet+ to store the paths in its context.
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

    def find_file(path, prefixes = [], *args)
      _find_all(path, prefixes, args, true).first || raise(MissingTemplate.new(self, path, prefixes, *args))
    end

    def find_all(path, prefixes = [], *args)
      _find_all path, prefixes, args, false
    end

    def exists?(path, prefixes, *args)
      find_all(path, prefixes, *args).any?
    end

    def find_all_with_query(query) # :nodoc:
      paths.each do |resolver|
        templates = resolver.find_all_with_query(query)
        return templates unless templates.empty?
      end

      []
    end

    private

    def _find_all(path, prefixes, args, outside_app)
      prefixes = [prefixes] if String === prefixes
      prefixes.each do |prefix|
        paths.each do |resolver|
          if outside_app
            templates = resolver.find_all_anywhere(path, prefix, *args)
          else
            templates = resolver.find_all(path, prefix, *args)
          end
          return templates unless templates.empty?
        end
      end
      []
    end

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
