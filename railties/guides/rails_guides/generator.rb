module RailsGuides
  class Generator
    attr_reader :output, :view_path, :view, :guides_dir

    def initialize(output = nil)
      @guides_dir = File.join(File.dirname(__FILE__), '..')

      @output = output || File.join(@guides_dir, "output")

      unless ENV["ONLY"]
        FileUtils.rm_r(@output) if File.directory?(@output)
        FileUtils.mkdir(@output)
      end

      @view_path = File.join(@guides_dir, "source")
    end

    def generate
      guides = Dir.entries(view_path).find_all {|g| g =~ /textile$/ }

      if ENV["ONLY"]
        only = ENV["ONLY"].split(",").map{|x| x.strip }.map {|o| "#{o}.textile" }
        guides = guides.find_all {|g| only.include?(g) }
        puts "GENERATING ONLY #{guides.inspect}"
      end

      guides.each do |guide|
        guide =~ /(.*?)(\.erb)?\.textile/
        name = $1

        puts "Generating #{name}"

        file = File.join(output, "#{name}.html")
        File.open(file, 'w') do |f|
          @view = ActionView::Base.new(view_path)
          @view.extend(Helpers)

          if guide =~ /\.erb\.textile/
            # Generate the erb pages with textile formatting - e.g. index/authors
            result = view.render(:layout => 'layout', :file => guide)
            f.write textile(result)
          else
            body = File.read(File.join(view_path, guide))
            body = set_header_section(body, @view)
            body = set_index(body, @view)

            result = view.render(:layout => 'layout', :text => textile(body))
            f.write result
          end
        end
      end

      # Copy images and css files to html directory
      FileUtils.cp_r File.join(guides_dir, 'images'), File.join(output, 'images')
      FileUtils.cp_r File.join(guides_dir, 'files'), File.join(output, 'files')
    end

    def set_header_section(body, view)
      new_body = body.gsub(/(.*?)endprologue\./m, '').strip
      header = $1

      header =~ /h2\.(.*)/
      page_title = $1.strip

      header = textile(header)

      view.content_for(:page_title) { page_title }
      view.content_for(:header_section) { header }
      new_body
    end

    def set_index(body, view)
      index = <<-INDEX
      <div id="subCol">
        <h3 class="chapter"><img src="images/chapters_icon.gif" alt="" /> Chapters</h3>
        <ol class="chapters">
  INDEX

      i = Indexer.new(body)
      i.index

      # Set index for 2 levels
      i.level_hash.each do |key, value|
        bookmark = '#' + key.gsub(/[^a-z0-9\-_\+]+/i, '').underscore.dasherize
        link = view.content_tag(:a, :href => bookmark) { key }

        children = value.keys.map do |k|
          bm = '#' + k.gsub(/[^a-z0-9\-_\+]+/i, '').underscore.dasherize
          l = view.content_tag(:a, :href => bm) { k }
          view.content_tag(:li, l)
        end

        children_ul = view.content_tag(:ul, children)

        index << view.content_tag(:li, link + children_ul)
      end

      index << '</ol>'
      index << '</div>'

      view.content_for(:index_section) { index }

      i.result
    end

    def textile(body)
      t = RedCloth.new(body)
      t.hard_breaks = false
      t.to_html(:notestuff, :plusplus, :code, :tip)
    end
  end
end
