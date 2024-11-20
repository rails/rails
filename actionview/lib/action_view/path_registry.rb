# frozen_string_literal: true

module ActionView # :nodoc:
  module PathRegistry # :nodoc:
    @view_paths_by_class = {}
    @file_system_resolvers = {}
    @file_system_resolver_mutex = Mutex.new
    @file_system_resolver_hooks = []

    class << self
      attr_reader :file_system_resolver_hooks
    end

    def self.get_view_paths(klass)
      @view_paths_by_class[klass] || get_view_paths(klass.superclass)
    end

    def self.set_view_paths(klass, paths)
      @view_paths_by_class[klass] = paths
    end

    def self.cast_file_system_resolvers(paths)
      paths = Array(paths)

      @file_system_resolver_mutex.synchronize do
        built_resolver = false
        paths = paths.map do |path|
          case path
          when String, Pathname
            path = File.expand_path(path)
            @file_system_resolvers[path] ||=
              begin
                built_resolver = true
                FileSystemResolver.new(path)
              end
          else
            path
          end
        end

        file_system_resolver_hooks.each(&:call) if built_resolver
      end

      paths
    end

    def self.all_resolvers
      resolvers = [all_file_system_resolvers]
      resolvers.concat @view_paths_by_class.values.map(&:to_a)
      resolvers.flatten.uniq
    end

    def self.all_file_system_resolvers
      @file_system_resolvers.values
    end
  end
end
