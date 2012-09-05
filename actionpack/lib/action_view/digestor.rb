module ActionView
  class Digestor
    EXPLICIT_DEPENDENCY = /# Template Dependency: ([^ ]+)/

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
      ([@a-z"'][@a-z_\/\."']+)      # the template name itself -- 2nd capture
    /x

    cattr_reader(:cache)
    @@cache = Hash.new

    def self.digest(name, format, finder, options = {})
      cache["#{name}.#{format}"] ||= new(name, format, finder, options).digest
    end

    attr_reader :name, :format, :finder, :options

    def initialize(name, format, finder, options = {})
      @name, @format, @finder, @options = name, format, finder, options
    end

    def digest
      Digest::MD5.hexdigest("#{source}-#{dependency_digest}").tap do |digest|
        logger.try :info, "Cache digest for #{name}.#{format}: #{digest}"
      end
    rescue ActionView::MissingTemplate
      logger.try :error, "Couldn't find template for digesting: #{name}.#{format}"
      ''
    end

    def dependencies
      render_dependencies + explicit_dependencies
    rescue ActionView::MissingTemplate
      [] # File doesn't exist, so no dependencies
    end

    def nested_dependencies
      dependencies.collect do |dependency|
        dependencies = Digestor.new(dependency, format, finder, partial: true).nested_dependencies
        dependencies.any? ? { dependency => dependencies } : dependency
      end
    end

    private

      def logger
        ActionView::Base.logger
      end

      def logical_name
        name.gsub(%r|/_|, "/")
      end

      def directory
        name.split("/").first
      end

      def partial?
        options[:partial] || name.include?("/_")
      end

      def source
        @source ||= finder.find(logical_name, [], partial?, formats: [ format ]).source
      end

      def dependency_digest
        dependencies.collect do |template_name|
          Digestor.digest(template_name, format, finder, partial: true)
        end.join("-")
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
end
