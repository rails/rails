# frozen_string_literal: true

module ActionView # :nodoc:
  # = Action View PathSet
  #
  # This class is used to store and access paths in Action View. A number of
  # operations are defined so that you can search among the paths in this
  # set and also perform operations on other +PathSet+ objects.
  #
  # A +LookupContext+ will use a +PathSet+ to store the paths in its context.
  class PathSet # :nodoc:
    include Enumerable

    EMPTY_PREFIXES = [""].freeze

    attr_reader :paths

    delegate :[], :include?, :size, :each, to: :paths

    def initialize(paths = [])
      @paths = typecast(paths).freeze
    end

    def initialize_copy(other)
      @paths = other.paths.dup.freeze
      self
    end

    def to_ary
      paths.dup
    end

    def compact
      PathSet.new paths.compact
    end

    def +(other)
      array = Array === other ? other : other.paths
      PathSet.new(paths + array)
    end

    def find(path, prefixes, partial, details, details_key, locals)
      search_combinations(path, prefixes, paths) do |resolver, name, prefix|
        resolver.find(name, prefix, partial, details, details_key, locals)
      end
    end

    def find!(path, prefixes, partial, details, details_key, locals)
      find(path, prefixes, partial, details, details_key, locals) ||
        raise(missing_template(path, prefixes, partial, details, details_key, locals))
    end

    def find_all(path, prefixes, partial, details, details_key, locals)
      search_combinations(path, prefixes, paths) do |resolver, name, prefix|
        templates = resolver.find_all(name, prefix, partial, details, details_key, locals)
        templates unless templates.empty?
      end || []
    end

    def exists?(path, prefixes, partial, details, details_key, locals)
      !find(path, prefixes, partial, details, details_key, locals).nil?
    end

    private
      # Combines each prefix as it is yielded rather than up front, since
      # callers stop at the first hit.
      def search_combinations(path, prefixes, resolvers)
        path = path.to_s
        idx = path.rindex("/")
        prefixes = Array(prefixes)

        if idx
          path_prefix = path[0, idx]
          path_prefix = path_prefix.from(1) if path_prefix.start_with?("/")
          name = path.from(idx + 1)
        else
          name = path
        end

        i = 0
        count = prefixes.empty? ? 1 : prefixes.length

        while i < count
          prefix =
            if prefixes.empty?
              path_prefix || ""
            elsif path_prefix
              "#{prefixes[i]}/#{path_prefix}"
            else
              prefixes[i]
            end

          j = 0
          while j < resolvers.length
            found = yield resolvers[j], name, prefix
            return found if found
            j += 1
          end

          i += 1
        end

        nil
      end

      def missing_template(path, prefixes, partial, details, details_key, locals)
        name = nil
        searched = []
        # A single placeholder resolver, so each prefix is listed once.
        search_combinations(path, prefixes, [nil]) do |_resolver, normalized, prefix|
          name = normalized
          searched << prefix
          nil
        end
        MissingTemplate.new(self, name, searched, partial, details, details_key, locals)
      end

      def typecast(paths)
        paths.map do |path|
          case path
          when Pathname, String
            # This path should only be reached by "direct" users of
            # ActionView::Base (not using the ViewPaths or Renderer modules).
            # We can't cache/de-dup the file system resolver in this case as we
            # don't know which compiled_method_container we'll be rendering to.
            FileSystemResolver.new(path)
          when Resolver
            path
          else
            raise TypeError, "#{path.inspect} is not a valid path: must be a String, Pathname, or Resolver"
          end
        end
      end
  end
end
