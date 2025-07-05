# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  # # Extract file and line from a trace and open it in the editor
  #
  # This is used to open the file in the editor when the user clicks on the edit icon. You have to set the `EDITOR` environment variable to the editor you want to use.
  class TraceToFileExtractor
    KNOWN_EDITORS = [
      { symbols: [:atom], sniff: /atom/i, url: "atom://core/open/file?filename=%{file}&line=%{line}" },
      { symbols: [:emacs, :emacsclient], sniff: /emacs/i, url: "emacs://open?url=file://%{file}&line=%{line}" },
      { symbols: [:idea], sniff: /idea/i, url: "idea://open?file=%{file}&line=%{line}" },
      { symbols: [:macvim, :mvim], sniff: /vim/i, url: "mvim://open?url=file://%{file_unencoded}&line=%{line}" },
      { symbols: [:rubymine], sniff: /mine/i, url: "x-mine://open?file=%{file}&line=%{line}" },
      { symbols: [:sublime, :subl, :st], sniff: /subl/i, url: "subl://open?url=file://%{file}&line=%{line}" },
      { symbols: [:textmate, :txmt, :tm], sniff: /mate/i, url: "txmt://open?url=file://%{file}&line=%{line}" },
      { symbols: [:vscode, :code], sniff: /code/i, url: "vscode://file/%{file}:%{line}" },
      { symbols: [:vscodium, :codium], sniff: /codium/i, url: "vscodium://file/%{file}:%{line}" },
      { symbols: [:windsurf], sniff: /windsurf/i, url: "windsurf://file/%{file}:%{line}" },
      { symbols: [:zed], sniff: /zed/i, url: "zed://file/%{file}:%{line}" },
      { symbols: [:nova], sniff: /nova/i, url: "nova://open?path=%{file}&line=%{line}" },
      { symbols: [:cursor], sniff: /cursor/i, url: "cursor://file/%{file}:%{line}" },
    ]

    class << self
      def open_in_editor?
        editor.present?
      end

      def editor
        @editor ||= ENV["EDITOR"].present? && KNOWN_EDITORS.find { |editor| editor[:symbols].include?(ENV["EDITOR"].to_sym) }
      end
    end

    def initialize(trace, line_number: nil)
      @trace = trace.to_s.strip
      @line_number = line_number
    end

    def call
      return nil unless self.class.open_in_editor?

      file_name = file_name_in_the_trace
      return nil if file_name.blank?

      case detect_trace_type
      when :gem_reference
        gem_name = trace.split(" ").first
        gem_spec = Gem.loaded_specs[gem_name]
        file_name = gem_spec.present? ? "#{gem_spec.full_gem_path}/#{file_name}" : nil
      when :app_code
        file_name = "#{Rails.root}/#{file_name}"
      when :direct_path
        # do nothing, we already have the full path
      end

      if file_name
        file, line = file_name.split(":")

        self.class.editor[:url] % { file: file, line: line_number || line }
      else
        # skip
      end
    end

    private
      attr_reader :trace, :line_number

      def detect_trace_type
        if trace[0] == "/" || trace.match?(/^[A-Z]:/)
          # to match linux and windows paths
          :direct_path
        elsif trace.split(" ")[1].present? && trace.split(" ")[1].match?(/\(([0-9.]*\))/)
          :gem_reference
        else
          :app_code
        end
      end

      def file_name_in_the_trace
        @file_name_in_the_trace ||= trace.split(" ").find { |part| part.match?(/\.\w+:\d+/) }.to_s.split(":in")[0]
      end
  end
end
