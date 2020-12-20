# frozen_string_literal: true

require "rouge"

# Add more common shell commands
Rouge::Lexers::Shell::BUILTINS << "|bin/rails|brew|bundle|gem|git|node|rails|rake|ruby|sqlite3|yarn"

module RailsGuides
  class Markdown
    class Renderer < Redcarpet::Render::HTML
      cattr_accessor :edge, :version

      def block_code(code, language)
        formatter = Rouge::Formatters::HTML.new
        lexer = ::Rouge::Lexer.find_fancy(lexer_language(language))
        formatted_code = formatter.format(lexer.lex(code))
        clipboard_id = "clipboard-#{SecureRandom.hex(16)}"
        <<~HTML
          <div class="code_container">
          <pre><code class="highlight #{lexer_language(language)}">#{formatted_code}</code></pre>
          <textarea class="clipboard-content" id="#{clipboard_id}">#{clipboard_content(code, language)}</textarea>
          <button class="clipboard-button" data-clipboard-target="##{clipboard_id}">Copy</button>
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
        # Always increase the heading level by 1, so we can use h1, h2 heading in the document
        header_level += 1

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
          prompt_regexp =
            case language
            when "bash"
              /^\$ /
            when "irb"
              /^irb.*?> /
            end

          if prompt_regexp
            code = code.lines.grep(prompt_regexp).join.gsub(prompt_regexp, "")
          end

          ERB::Util.h(code)
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
            %(<div class="#{css_class}"><p>#{$2.strip}</p></div>)
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
    end
  end
end
