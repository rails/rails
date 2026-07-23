# frozen_string_literal: true

require "action_view/path_set"
require "action_view/render_parser"

module ActionView
  # = Action View Dependency Tracker
  #
  # When the digestor builds a template's dependency tree (to compute the cache
  # keys used by +cache+ blocks and +stale?+ checks), it asks the dependency
  # tracker which other templates a given template renders.
  #
  # Dependencies are tracked per template handler, because every template
  # language spells +render+ differently. Action View ships ERBTracker for ERB;
  # handlers for other template languages register their own with
  # ::register_tracker, typically from an +ActiveSupport.on_load(:action_view)+
  # block so it runs once Action View is available:
  #
  #   ActiveSupport.on_load(:action_view) do
  #     ActionView::Template.register_template_handler :mtl, MyTemplateLanguage::Handler
  #     ActionView::DependencyTracker.register_tracker :mtl, MyTemplateLanguage::DependencyTracker
  #   end
  #
  # Languages whose +render+ calls look like Ruby's can register ERBTracker
  # instead of writing their own tracker.
  class DependencyTracker
    extend ActiveSupport::Autoload

    autoload :ERBTracker
    autoload :RubyTracker
    autoload :WildcardResolver

    @trackers = {}

    def self.find_dependencies(name, template, view_paths = nil) # :nodoc:
      tracker = @trackers[template.handler]
      return [] unless tracker

      tracker.call(name, template, view_paths)
    end

    # Registers the +tracker+ used to find the dependencies of templates
    # rendered by the handler registered for +extension+.
    #
    # +tracker+ is any object that responds to
    # +call(name, template, view_paths)+ and returns the array of template
    # names +template+ depends on. An object responding only to
    # +call(name, template)+ is also accepted for backwards compatibility.
    def self.register_tracker(extension, tracker)
      handler = Template.handler_for_extension(extension)
      callable = if tracker.respond_to?(:supports_view_paths?)
        tracker
      else
        ActiveSupport::Ractors.try_shareable_proc { |name, template, _|
          tracker.call(name, template)
        }
      end

      if @trackers.frozen?
        ActionView.deprecator.warn(<<~MSG)
          Registering a dependency tracker after the application has booted is deprecated.
          Register trackers from a Railtie or an initializer instead.
        MSG
        @trackers = @trackers.merge(handler => callable).freeze
      else
        @trackers[handler] = callable
      end
    end

    def self.remove_tracker(handler) # :nodoc:
      if @trackers.frozen?
        @trackers = @trackers.except(handler).freeze
      else
        @trackers.delete(handler)
      end
    end

    def self.freeze_registry # :nodoc:
      @trackers.freeze
    end

    def self.share_registry # :nodoc:
      ActiveSupport::Ractors.make_shareable(@trackers)
    end

    case ActionView.render_tracker
    when :ruby
      register_tracker :erb, RubyTracker
    else
      register_tracker :erb, ERBTracker
    end
  end
end
