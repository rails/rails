# frozen_string_literal: true

require "concurrent/map"
require "action_view/path_set"
require "action_view/render_parser"

module ActionView
  class DependencyTracker # :nodoc:
    extend ActiveSupport::Autoload

    autoload :ERBTracker
    autoload :RipperTracker

    @trackers = Concurrent::Map.new

    def self.find_dependencies(name, template, view_paths = nil)
      tracker = @trackers[template.handler]
      return [] unless tracker

      tracker.call(name, template, view_paths)
    end

    def self.register_tracker(extension, tracker)
      handler = Template.handler_for_extension(extension)
      if tracker.respond_to?(:supports_view_paths?)
        @trackers[handler] = tracker
      else
        @trackers[handler] = lambda { |name, template, _|
          tracker.call(name, template)
        }
      end
    end

    def self.remove_tracker(handler)
      @trackers.delete(handler)
    end

    register_tracker :erb, ERBTracker
  end
end
