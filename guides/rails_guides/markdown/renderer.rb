# frozen_string_literal: true

require "rouge"

# Add more common shell commands
Rouge::Lexers::Shell::BUILTINS << "|bin/rails|brew|bundle|gem|git|node|rails|rake|ruby|sqlite3|yarn"

# Register an IRB lexer for Rails 7.2+ console prompts like "store(dev)>"
class Rouge::Lexers::GuidesIRBLexer < Rouge::Lexers::IRBLexer
  tag "irb"

  def prompt_regex
    %r(
      ^.*?
      (
        (irb|pry|\w+\(\w+\)).*?[>"*] |
        [>"*]>
      )
    )x
  end
end

module RailsGuides
  class Markdown
    class Renderer < Redcarpet::Render::HTML  # :nodoc:
      APPLICATION_FILEPATH_REGEXP = /(app|config|db|lib|test)\//
      ERB_FILEPATH_REGEXP = /^<%# #{APPLICATION_FILEPATH_REGEXP}.* %>/o
      RUBY_FILEPATH_REGEXP = /^# #{APPLICATION_FILEPATH_REGEXP}/o

      cattr_accessor :edge, :version

      def block_code(code, language)
        language, lines = split_language_highlights(language)
        formatter = Rouge::Formatters::HTMLLineHighlighter.new(Rouge::Formatters::HTML.new, highlight_lines: lines)
        lexer = ::Rouge::Lexer.find_fancy(lexer_language(language))
        formatted_code = formatter.format(lexer.lex(code))
        <<~HTML
          <div class="interstitial code">
          <pre><code class="highlight #{lexer_language(language)}">#{formatted_code}</code></pre>
          <button class="clipboard-button" data-clipboard-text="#{clipboard_content(code, language)}">Copy</button>
          </div>
        HTML
      end

      def link(url, title, content)
        if %r{https?://api\.rubyonrails\.org}.match?(url)
          %(<a href="#{api_link(url)}">#{content}</a>)
        elsif title
          %(<a href="#{url}" title="#{title}">#{content}</a>)
        else
          %(<a href="#{url}">#{content}</a>)
        end
      end

      def header(text, header_level)
        header_with_id = text.scan(/(.*){#(.*)}/)
        unless header_with_id.empty?
          %(<h#{header_level} id="#{header_with_id[0][1].strip}">#{header_with_id[0][0].strip}</h#{header_level}>)
        else
          %(<h#{header_level}>#{text}</h#{header_level}>)
        end
      end

      def paragraph(text)
        if text =~ %r{^NOTE:\s+Defined\s+in\s+<code>(.*?)</code>\.?$}
          %(<div class="note"><p>Defined in <code><a href="#{github_file_url($1)}">#{$1}</a></code>.</p></div>)
        elsif /^(TIP|IMPORTANT|CAUTION|WARNING|NOTE|INFO|TODO)[.:]/.match?(text)
          convert_notes(text)
        elsif text.include?("DO NOT READ THIS FILE ON GITHUB")
        elsif text =~ /^\[<sup>(\d+)\]:<\/sup> (.+)$/
          linkback = %(<a href="#footnote-#{$1}-ref"><sup>#{$1}</sup></a>)
          %(<p class="footnote" id="footnote-#{$1}">#{linkback} #{$2}</p>)
        else
          text = convert_footnotes(text)
          "<p>#{text}</p>"
        end
      end

      private
        def convert_footnotes(text)
          text.gsub(/\[<sup>(\d+)\]<\/sup>/i) do
            %(<sup class="footnote" id="footnote-#{$1}-ref">) +
              %(<a href="#footnote-#{$1}">#{$1}</a></sup>)
          end
        end

        def lexer_language(code_type)
          case code_type
          when "html+erb"
            "erb"
          when "bash"
            "console"
          when nil
            "plaintext"
          else
            ::Rouge::Lexer.find(code_type) ? code_type : "plaintext"
          end
        end

        def clipboard_content(code, language)
          # Remove prompt and results of commands.
          prompt_regexp =
            case language
            when "bash"
              /^\$ /
            when "irb"
              /^(irb.*?|\w+\(\w+\))> /
            end

          if prompt_regexp
            code = code.lines.grep(prompt_regexp).join.gsub(prompt_regexp, "")
          end

          # Remove comments that reference an application file.
          filepath_regexp =
            case language
            when "erb", "html+erb"
              ERB_FILEPATH_REGEXP
            when "ruby", "yaml", "yml"
              RUBY_FILEPATH_REGEXP
            end

          if filepath_regexp
            code = code.lines.grep_v(filepath_regexp).join
          end

          ERB::Util.html_escape(code)
        end

        def convert_notes(body)
          # The following regexp detects special labels followed by a
          # paragraph, perhaps at the end of the document.
          #
          # It is important that we do not eat more than one newline
          # because formatting may be wrong otherwise. For example,
          # if a bulleted list follows, the first item is not rendered
          # as a list item, but as a paragraph starting with a plain
          # asterisk.
          body.gsub(/^(TIP|IMPORTANT|CAUTION|WARNING|NOTE|INFO|TODO)[.:](.*?)(\n(?=\n)|\Z)/m) do
            css_class = \
              case $1
              when "CAUTION", "IMPORTANT"
                "warning"
              when "TIP"
                "info"
              else
                $1.downcase
              end
            %(<div class="interstitial #{css_class}"><p>#{$2.strip}</p></div>)
          end
        end

        def github_file_url(file_path)
          tree = version || edge

          root = file_path[%r{(\w+)/}, 1]
          path = \
            case root
            when "abstract_controller", "action_controller", "action_dispatch"
              "actionpack/lib/#{file_path}"
            when /\A(action|active)_/
              "#{root.sub("_", "")}/lib/#{file_path}"
            else
              file_path
            end

          "https://github.com/rails/rails/tree/#{tree}/#{path}"
        end

        def api_link(url)
          if %r{https?://api\.rubyonrails\.org/v\d+\.}.match?(url)
            url
          elsif edge
            url.sub("api", "edgeapi")
          else
            url.sub(/(?<=\.org)/, "/#{version}")
          end
        end

        # Parses "ruby#3,5-6,10" into ["ruby", [3,5,6,10]] for highlighting line numbers in code blocks
        def split_language_highlights(language)
          return [nil, []] unless language

          language, lines = language.split("#", 2)
          lines = lines.to_s.split(",").flat_map { parse_range(_1) }

          [language, lines]
        end

        def parse_range(range)
          first, last = range.split("-", 2).map(&:to_i)
          Range.new(first, last || first).to_a
        end
    end
  end
end
