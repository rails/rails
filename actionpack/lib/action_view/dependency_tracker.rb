require 'thread_safe'

module ActionView
  class DependencyTracker
    @trackers = ThreadSafe::Cache.new

    def self.find_dependencies(name, template)
      tracker = @trackers[template.handler]

      if tracker.present?
        tracker.call(name, template)
      else
        []
      end
    end

    def self.register_tracker(extension, tracker)
      handler = Template.handler_for_extension(extension)
      @trackers[handler] = tracker
    end

    def self.remove_tracker(handler)
      @trackers.delete(handler)
    end

    class ERBTracker
      EXPLICIT_DEPENDENCY = /# Template Dependency: (\S+)/

      # Matches:
      #   render partial: "comments/comment", collection: commentable.comments
      #   render "comments/comments"
      #   render 'comments/comments'
      #   render('comments/comments')
      #
      #   render(@topic)         => render("topics/topic")
      #   render(topics)         => render("topics/topic")
      #   render(message.topics) => render("topics/topic")
      RENDER_DEPENDENCY = /
        render\s*                     # render, followed by optional whitespace
        \(?                           # start an optional parenthesis for the render call
        (partial:|:partial\s+=>)?\s*  # naming the partial, used with collection -- 1st capture
        ([@a-z"'][@\w\/\."']+)        # the template name itself -- 2nd capture
      /x

      def self.call(name, template)
        new(name, template).dependencies
      end

      def initialize(name, template)
        @name, @template = name, template
      end

      def dependencies
        render_dependencies + explicit_dependencies
      end

      attr_reader :name, :template
      private :name, :template

      private

        def source
          template.source
        end

        def directory
          name.split("/")[0..-2].join("/")
        end

        def render_dependencies
          source.scan(RENDER_DEPENDENCY).
            collect(&:second).uniq.

            # render(@topic)         => render("topics/topic")
            # render(topics)         => render("topics/topic")
            # render(message.topics) => render("topics/topic")
            collect { |name| name.sub(/\A@?([a-z]+\.)*([a-z_]+)\z/) { "#{$2.pluralize}/#{$2.singularize}" } }.

            # render("headline") => render("message/headline")
            collect { |name| name.include?("/") ? name : "#{directory}/#{name}" }.

            # replace quotes from string renders
            collect { |name| name.gsub(/["']/, "") }
        end

        def explicit_dependencies
          source.scan(EXPLICIT_DEPENDENCY).flatten.uniq
        end
    end

    register_tracker :erb, ERBTracker
  end
end
