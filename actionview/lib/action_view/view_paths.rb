# frozen_string_literal: true

module ActionView
  module ViewPaths
    extend ActiveSupport::Concern

    included do
      ViewPaths.set_view_paths(self, ActionView::PathSet.new.freeze)
    end

    delegate :template_exists?, :any_templates?, :view_paths, :formats, :formats=,
             :locale, :locale=, to: :lookup_context

    module ClassMethods
      def _view_paths
        ViewPaths.get_view_paths(self)
      end

      def _view_paths=(paths)
        ViewPaths.set_view_paths(self, paths)
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

    # :stopdoc:
    @all_view_paths = {}

    def self.get_view_paths(klass)
      @all_view_paths[klass] || get_view_paths(klass.superclass)
    end

    def self.set_view_paths(klass, paths)
      @all_view_paths[klass] = paths
    end

    def self.all_view_paths
      @all_view_paths.values.uniq
    end
    # :startdoc:

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
