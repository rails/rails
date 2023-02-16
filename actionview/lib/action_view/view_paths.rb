# frozen_string_literal: true

module ActionView
  module ViewPaths
    extend ActiveSupport::Concern

    included do
      ViewPaths::Registry.set_view_paths(self, ActionView::PathSet.new.freeze)
    end

    delegate :template_exists?, :any_templates?, :view_paths, :formats, :formats=,
             :locale, :locale=, to: :lookup_context

    module ClassMethods
      def _view_paths
        ViewPaths::Registry.get_view_paths(self)
      end

      def _view_paths=(paths)
        ViewPaths::Registry.set_view_paths(self, paths)
      end

      def _prefixes # :nodoc:
        @_prefixes ||= begin
          return local_prefixes if superclass.abstract?

          local_prefixes + superclass._prefixes
        end
      end

      # Append a path to the list of view paths for this controller.
      #
      # ==== Parameters
      # * <tt>path</tt> - If a String is provided, it gets converted into
      #   the default view path. You may also provide a custom view path
      #   (see ActionView::PathSet for more information)
      def append_view_path(path)
        self._view_paths = ActionView::PathSet.new(view_paths.to_a + Array(path))
      end

      # Prepend a path to the list of view paths for this controller.
      #
      # ==== Parameters
      # * <tt>path</tt> - If a String is provided, it gets converted into
      #   the default view path. You may also provide a custom view path
      #   (see ActionView::PathSet for more information)
      def prepend_view_path(path)
        self._view_paths = ActionView::PathSet.new(Array(path) + view_paths.to_a)
      end

      # A list of all of the default view paths for this controller.
      def view_paths
        _view_paths
      end

      # Set the view paths.
      #
      # ==== Parameters
      # * <tt>paths</tt> - If a PathSet is provided, use that;
      #   otherwise, process the parameter into a PathSet.
      def view_paths=(paths)
        self._view_paths = ActionView::PathSet.new(Array(paths))
      end

      private
        # Override this method in your controller if you want to change paths prefixes for finding views.
        # Prefixes defined here will still be added to parents' <tt>._prefixes</tt>.
        def local_prefixes
          [controller_path]
        end
    end

    module Registry # :nodoc:
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

    # The prefixes used in render "foo" shortcuts.
    def _prefixes # :nodoc:
      self.class._prefixes
    end

    # LookupContext is the object responsible for holding all
    # information required for looking up templates, i.e. view paths and
    # details. Check ActionView::LookupContext for more information.
    def lookup_context
      @_lookup_context ||=
        ActionView::LookupContext.new(self.class._view_paths, details_for_lookup, _prefixes)
    end

    def details_for_lookup
      {}
    end

    # Append a path to the list of view paths for the current LookupContext.
    #
    # ==== Parameters
    # * <tt>path</tt> - If a String is provided, it gets converted into
    #   the default view path. You may also provide a custom view path
    #   (see ActionView::PathSet for more information)
    def append_view_path(path)
      lookup_context.append_view_paths(Array(path))
    end

    # Prepend a path to the list of view paths for the current LookupContext.
    #
    # ==== Parameters
    # * <tt>path</tt> - If a String is provided, it gets converted into
    #   the default view path. You may also provide a custom view path
    #   (see ActionView::PathSet for more information)
    def prepend_view_path(path)
      lookup_context.prepend_view_paths(Array(path))
    end
  end
end
