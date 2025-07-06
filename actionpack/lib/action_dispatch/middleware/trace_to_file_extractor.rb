# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  # # Extract file and line from a trace and open it in the editor
  #
  # This is used to open the file in the editor when the user clicks on the edit icon. You have to set the `EDITOR` environment variable to the editor you want to use.
  class TraceToFileExtractor
    KNOWN_EDITORS = [
      { symbols: [:atom], url: "atom://core/open/file?filename=%{file}&line=%{line}" },
      { symbols: [:emacs, :emacsclient], url: "emacs://open?url=file://%{file}&line=%{line}" },
      { symbols: [:idea], url: "idea://open?file=%{file}&line=%{line}" },
      { symbols: [:macvim, :mvim], url: "mvim://open?url=file://%{file_unencoded}&line=%{line}" },
      { symbols: [:rubymine], url: "x-mine://open?file=%{file}&line=%{line}" },
      { symbols: [:sublime, :subl, :st], url: "subl://open?url=file://%{file}&line=%{line}" },
      { symbols: [:textmate, :txmt, :tm], url: "txmt://open?url=file://%{file}&line=%{line}" },
      { symbols: [:vscode, :code], url: "vscode://file/%{file}:%{line}" },
      { symbols: [:vscodium, :codium], url: "vscodium://file/%{file}:%{line}" },
      { symbols: [:windsurf], url: "windsurf://file/%{file}:%{line}" },
      { symbols: [:zed], url: "zed://file/%{file}:%{line}" },
      { symbols: [:nova], url: "nova://open?path=%{file}&line=%{line}" },
      { symbols: [:cursor], url: "cursor://file/%{file}:%{line}" },
    ]

    class << self
      def call(trace, line_number: nil)
        link_format && link_format % { file: trace.absolute_path, line: line_number || trace.lineno }
      end

      private
      def editor
        @editor ||= ENV["EDITOR"].present? && KNOWN_EDITORS.find { |editor| editor[:symbols].include?(ENV["EDITOR"].to_sym) }
      end

      # If we want to define a custom link format, we can set the `RAILS_FILE_LINK_FORMAT` environment variable.
      # It should be a string with `%{file}` and `%{line}` placeholders.
      def link_format
        @link_format ||= (editor && editor&.dig(:url)) || ENV["RAILS_FILE_LINK_FORMAT"]
      end
    end
  end
end
