require 'set'
require 'fileutils'

require 'active_support/core_ext/string/output_safety'
require 'action_controller'
require 'action_view'

require 'rails_guides/indexer'
require 'rails_guides/helpers'
require 'rails_guides/levenshtein'

module RailsGuides
  class Generator
    attr_reader :guides_dir, :source_dir, :output_dir 

    def initialize(output=nil)
      initialize_dirs(output)
      reset_output_dir
    end

    def generate
      generate_guides
      copy_assets
    end

    private
    def initialize_dirs(output)
      @guides_dir = File.join(File.dirname(__FILE__), '..')
      @source_dir = File.join(@guides_dir, "source")
      @output_dir = output || File.join(@guides_dir, "output")      
    end

    def reset_output_dir
      FileUtils.rm_rf(output_dir)
      FileUtils.mkdir_p(output_dir)
    end  

    def generate_guides
      guides_to_generate.each do |guide|
        generate_guide(guide)
      end
    end

    def guides_to_generate
      guides = Dir.entries(source_dir).grep(/\.textile(?:\.erb)?$/)
      ENV.key?("ONLY") ? select_only(guides) : guides
    end

    def select_only(guides)
      prefixes = ENV["ONLY"].split(",").map(&:strip)
      guides.select do |guide|
        prefixes.any? {|p| guide.start_with?(p)}
      end
    end

    def copy_assets
      FileUtils.cp_r(File.join(guides_dir, 'images'), File.join(output_dir, 'images'))
      FileUtils.cp_r(File.join(guides_dir, 'files'), File.join(output_dir, 'files'))      
    end

    def generate_guide(guide)
      output_file = guide.sub(/\.textile(?:\.erb)?$/, '.html')
      puts "Generating #{output_file}"

      File.open(File.join(output_dir, output_file), 'w') do |f|
        view = ActionView::Base.new(source_dir)
        view.extend(Helpers)
        
        if guide =~ /\.textile\.erb$/
          # Generate the erb pages with textile formatting - e.g. index/authors
          result = view.render(:layout => 'layout', :file => guide)
          result = textile(result)
        else
          body = File.read(File.join(source_dir, guide))
          body = set_header_section(body, view)
          body = set_index(body, view)

          result = view.render(:layout => 'layout', :text => textile(body))

          warn_about_broken_links(result) if ENV.key?("WARN_BROKEN_LINKS")
        end
        
        result = insert_edge_badge(result) if ENV.key?('INSERT_EDGE_BADGE')
        f.write result
      end
    end

    def set_header_section(body, view)
      new_body = body.gsub(/(.*?)endprologue\./m, '').strip
      header = $1

      header =~ /h2\.(.*)/
      page_title = $1.strip

      header = textile(header)

      view.content_for(:page_title) { page_title.html_safe }
      view.content_for(:header_section) { header.html_safe }
      new_body
    end

    def set_index(body, view)
      index = <<-INDEX
      <div id="subCol">
        <h3 class="chapter"><img src="images/chapters_icon.gif" alt="" />Chapters</h3>
        <ol class="chapters">
      INDEX

      i = Indexer.new(body)
      i.index

      # Set index for 2 levels
      i.level_hash.each do |key, value|
        link = view.content_tag(:a, :href => key[:id]) { textile(key[:title]).html_safe }

        children = value.keys.map do |k|
          l = view.content_tag(:a, :href => k[:id]) { textile(k[:title]).html_safe }
          view.content_tag(:li, l.html_safe)
        end

        children_ul = view.content_tag(:ul, children.join(" ").html_safe)

        index << view.content_tag(:li, link.html_safe + children_ul.html_safe)
      end

      index << '</ol>'
      index << '</div>'

      view.content_for(:index_section) { index.html_safe }

      i.result
    end

    def textile(body)
      # If the issue with notextile is fixed just remove the wrapper.
      with_workaround_for_notextile(body) do |body|
        t = RedCloth.new(body)
        t.hard_breaks = false
        t.to_html(:notestuff, :plusplus, :code, :tip)
      end
    end

    # For some reason the notextile tag does not always turn off textile. See
    # LH ticket of the security guide (#7). As a temporary workaround we deal
    # with code blocks by hand.
    def with_workaround_for_notextile(body)
      code_blocks = []
      body.gsub!(%r{<(yaml|shell|ruby|erb|html|sql|plain)>(.*?)</\1>}m) do |m|
        es = ERB::Util.h($2)
        css_class = ['erb', 'shell'].include?($1) ? 'html' : $1
        code_blocks << %{<div class="code_container"><code class="#{css_class}">#{es}</code></div>}
        "\ndirty_workaround_for_notextile_#{code_blocks.size - 1}\n"
      end
      
      body = yield body
      
      body.gsub(%r{<p>dirty_workaround_for_notextile_(\d+)</p>}) do |_|
        code_blocks[$1.to_i]
      end
    end

    def warn_about_broken_links(html)
      anchors = extract_anchors(html)
      check_fragment_identifiers(html, anchors)
    end
    
    def extract_anchors(html)
      # Textile generates headers with IDs computed from titles.
      anchors = Set.new
      html.scan(/<h\d\s+id="([^"]+)/).flatten.each do |anchor|
        if anchors.member?(anchor)
          puts "*** DUPLICATE HEADER ID: #{anchor}, please consider rewording" if ENV.key?("WARN_DUPLICATE_HEADERS")
        else
          anchors << anchor
        end
      end

      # Also, footnotes are rendered as paragraphs this way.
      anchors += Set.new(html.scan(/<p\s+class="footnote"\s+id="([^"]+)/).flatten)
      return anchors
    end
    
    def check_fragment_identifiers(html, anchors)
      html.scan(/<a\s+href="#([^"]+)/).flatten.each do |fragment_identifier|
        next if fragment_identifier == 'mainCol' # in layout, jumps to some DIV
        unless anchors.member?(fragment_identifier)
          guess = anchors.min { |a, b|
            Levenshtein.distance(fragment_identifier, a) <=> Levenshtein.distance(fragment_identifier, b)
          }
          puts "*** BROKEN LINK: ##{fragment_identifier}, perhaps you meant ##{guess}."
        end
      end
    end
    
    def insert_edge_badge(html)
      html.sub(/<body[^>]*>/, '\&<img src="images/edge_badge.png" style="position:fixed; right:0px; top:0px; border:none; z-index:100"/>')
    end
  end
end
