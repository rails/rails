# frozen_string_literal: true

# :markup: markdown

module ActiveSupport
  class Editor
    @editors = {}
    @current = false

    class << self
      # Registers a URL pattern for opening file in a given editor.
      # This allows Rails to generate clickable links to control known editors.
      #
      # Example:
      #
      #  ActiveSupport::Editor.register("myeditor", "myeditor://%s:%d")
      def register(name, url_pattern, aliases: [])
        editor = new(url_pattern)
        @editors[name] = editor
        aliases.each do |a|
          @editors[a] = editor
        end
      end

      # Returns the current editor pattern if it is known.
      # First check for the `RAILS_EDITOR` environment variable, and if it's
      # missing, check for the `EDITOR` environment variable.
      def current
        if @current == false
          @current = if editor_name = ENV["RAILS_EDITOR"] || ENV["EDITOR"]
            @editors[editor_name]
          end
        end
        @current
      end

      # :nodoc:

      def find(name)
        @editors[name]
      end

      def reset
        @current = false
      end
    end

    def initialize(url_pattern)
      @url_pattern = url_pattern
    end

    def url_for(path, line)
      sprintf(@url_pattern, path, line)
    end

    register "atom", "atom://core/open/file?filename=%s&line=%d"
    register "cursor", "cursor://file/%s:%f"
    register "emacs", "emacs://open?url=file://%s&line=%d", aliases: ["emacsclient"]
    register "idea", "idea://open?file=%s&line=%d"
    register "macvim", "mvim://open?url=file://%s&line=%d", aliases: ["mvim"]
    register "nova", "nova://open?path=%s&line=%d"
    register "rubymine", "x-mine://open?file=%s&line=%d"
    register "sublime", "subl://open?url=file://%s&line=%d", aliases: ["subl"]
    register "textmate", "txmt://open?url=file://%s&line=%d", aliases: ["mate"]
    register "vscode", "vscode://file/%s:%d", aliases: ["code"]
    register "vscodium", "vscodium://file/%s:%d", aliases: ["codium"]
    register "windsurf", "windsurf://file/%s:%d"
    register "zed", "zed://file/%s:%d"
  end
end
