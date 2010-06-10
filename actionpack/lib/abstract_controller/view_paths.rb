module AbstractController
  module ViewPaths
    extend ActiveSupport::Concern

    included do
      class_attribute :_view_paths
      self._view_paths = ActionView::PathSet.new
      self._view_paths.freeze
    end

    delegate :find_template, :template_exists?, :view_paths, :formats, :formats=,
             :locale, :locale=, :to => :lookup_context

    # LookupContext is the object responsible to hold all information required to lookup
    # templates, i.e. view paths and details. Check ActionView::LookupContext for more
    # information.
    def lookup_context
      @lookup_context ||= ActionView::LookupContext.new(self.class._view_paths, details_for_lookup)
    end

    def details_for_lookup
      { }
    end

    def append_view_path(path)
      lookup_context.view_paths.push(*path)
    end

    def prepend_view_path(path)
      lookup_context.view_paths.unshift(*path)
    end

    module ClassMethods
      # Append a path to the list of view paths for this controller.
      #
      # ==== Parameters
      # path<String, ViewPath>:: If a String is provided, it gets converted into
      # the default view path. You may also provide a custom view path
      # (see ActionView::ViewPathSet for more information)
      def append_view_path(path)
        self.view_paths = view_paths.dup + Array(path)
      end

      # Prepend a path to the list of view paths for this controller.
      #
      # ==== Parameters
      # path<String, ViewPath>:: If a String is provided, it gets converted into
      # the default view path. You may also provide a custom view path
      # (see ActionView::ViewPathSet for more information)
      def prepend_view_path(path)
        self.view_paths = Array(path) + view_paths.dup
      end

      # A list of all of the default view paths for this controller.
      def view_paths
        _view_paths
      end

      # Set the view paths.
      #
      # ==== Parameters
      # paths<ViewPathSet, Object>:: If a ViewPathSet is provided, use that;
      #   otherwise, process the parameter into a ViewPathSet.
      def view_paths=(paths)
        self._view_paths = ActionView::Base.process_view_paths(paths)
        self._view_paths.freeze
      end
    end
  end
end