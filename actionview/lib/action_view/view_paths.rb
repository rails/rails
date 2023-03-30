# frozen_string_literal: true

module ActionView
  module ViewPaths
    extend ActiveSupport::Concern

    included do
      ActionView::PathRegistry.set_view_paths(self, ActionView::PathSet.new.freeze)
    end

    delegate :template_exists?, :any_templates?, :view_paths, :formats, :formats=,
             :locale, :locale=, to: :lookup_context

    module ClassMethods
      def _view_paths
        ActionView::PathRegistry.get_view_paths(self)
      end

      def _view_paths=(paths)
        ActionView::PathRegistry.set_view_paths(self, paths)
      end

      def _prefixes # :nodoc:
        @_prefixes ||= begin
          return local_prefixes if superclass.abstract?

          local_prefixes + superclass._prefixes
        end
      end

      def _build_view_paths(paths) # :nodoc:
        return paths if ActionView::PathSet === paths

        paths = ActionView::PathRegistry.cast_file_system_resolvers(paths)
        ActionView::PathSet.new(paths)
      end

      # Append a path to the list of view paths for this controller.
      #
      # ==== Parameters
      # * <tt>path</tt> - If a String is provided, it gets converted into
      #   the default view path. You may also provide a custom view path
      #   (see ActionView::PathSet for more information)
      def append_view_path(path)
        self._view_paths = view_paths + _build_view_paths(path)
      end

      # Prepend a path to the list of view paths for this controller.
      #
      # ==== Parameters
      # * <tt>path</tt> - If a String is provided, it gets converted into
      #   the default view path. You may also provide a custom view path
      #   (see ActionView::PathSet for more information)
      def prepend_view_path(path)
        self._view_paths = _build_view_paths(path) + view_paths
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
        self._view_paths = _build_view_paths(paths)
      end

      private
        # Override this method in your controller if you want to change paths prefixes for finding views.
        # Prefixes defined here will still be added to parents' <tt>._prefixes</tt>.
        def local_prefixes
          [controller_path]
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
      lookup_context.append_view_paths(self.class._build_view_paths(path))
    end

    # Prepend a path to the list of view paths for the current LookupContext.
    #
    # ==== Parameters
    # * <tt>path</tt> - If a String is provided, it gets converted into
    #   the default view path. You may also provide a custom view path
    #   (see ActionView::PathSet for more information)
    def prepend_view_path(path)
      lookup_context.prepend_view_paths(self.class._build_view_paths(path))
    end
  end
end
