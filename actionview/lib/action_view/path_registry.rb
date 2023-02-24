# frozen_string_literal: true

module ActionView # :nodoc:
  module PathRegistry # :nodoc:
    @view_paths_by_class = {}
    @file_system_resolvers = Concurrent::Map.new

    class << self
      include ActiveSupport::Callbacks
      define_callbacks :build_file_system_resolver
    end

    def self.get_view_paths(klass)
      @view_paths_by_class[klass] || get_view_paths(klass.superclass)
    end

    def self.set_view_paths(klass, paths)
      @view_paths_by_class[klass] = paths
    end

    def self.file_system_resolver(path)
      path = File.expand_path(path)
      resolver = @file_system_resolvers[path]
      unless resolver
        run_callbacks(:build_file_system_resolver) do
          resolver = @file_system_resolvers.fetch_or_store(path) do
            FileSystemResolver.new(path)
          end
        end
      end
      resolver
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
