module Rails
  class TemplateFinder
    attr_reader :app, :root

    def initialize(app)
      @app = app
      @root = app.root
    end

    def resolver
      paths.first
    end

    def paths
      @paths ||= ActionView::PathSet.new(
        [
          ActionView::OptimizedFileSystemResolver.new(app.paths["app/views"].to_a.first)
        ]
      )
    end

    def details_key
      ActionView::LookupContext::DetailsKey
    end

    def details
      {
        :locale=>[:en],
        :formats=>[:html],
        :variants=>[],
        :handlers=>[:raw, :erb, :html, :builder, :ruby, :coffee]
      }
    end
  end

  class FileTemplateFinder < TemplateFinder
    def templates
      paths = Dir.glob("#{root}/app/views/**/*.html.erb")
      paths.map do |template_path|
        name = get_name(template_path)
        prefix = get_prefix(template_path)
        partial = name.start_with?("_")
        key = details_key.get(details)
        locals = []

        name.sub!(/\_/, "") if partial

        template = resolver.find_all(name, prefix, partial, details, key, locals)

        template.present? ? template : nil
      end.compact.flatten
    end

    def get_name(template_path)
      template_path.split("/").last.split(".").first
    end

    def get_prefix(template_path)
      template_path.split("/")[-2]
    end
  end

  class TemplatePrecompiler
    extend Forwardable
    attr_reader :app, :finder

    def_delegator :@finder, :paths, :paths

    def initialize(app)
      @app = app
      @finder = FileTemplateFinder.new(app)
    end

    def compile_templates!
      templates.each do |template|
        template.send(:compile!, view_object)
      end
    end

    def templates
      @templates ||= finder.templates
    end

    def view_object
      @view_object ||= ActionView::Base.new(finder.paths, {})
    end
  end
end
