#!/usr/bin/env ruby

unless `which kindlerb`
  abort "Please gem install kindlerb"
end

require "nokogiri"
require "fileutils"
require "yaml"
require "date"

module Kindle
  extend self

  def generate(output_dir, mobi_outfile, logfile)
    output_dir = File.absolute_path(output_dir)
    Dir.chdir output_dir do
      puts "=> Using output dir: #{output_dir}"
      puts "=> Arranging html pages in document order"
      toc = File.read("toc.ncx")
      doc = Nokogiri::XML(toc).xpath("//ncx:content", "ncx" => "http://www.daisy.org/z3986/2005/ncx/")
      html_pages = doc.select { |c| c[:src] }.map { |c| c[:src] }.uniq

      generate_front_matter(html_pages)

      generate_sections(html_pages)

      generate_document_metadata(mobi_outfile)

      puts "Creating MOBI document with kindlegen. This may take a while."
      cmd = "kindlerb . > #{File.absolute_path logfile} 2>&1"
      puts cmd
      system(cmd)
      puts "MOBI document generated at #{File.expand_path(mobi_outfile, output_dir)}"
    end
  end

  def generate_front_matter(html_pages)
    frontmatter = []
    html_pages.delete_if { |x|
      if x =~ /(toc|welcome|credits|copyright).html/
        frontmatter << x unless x =~ /toc/
        true
      end
    }
    html = frontmatter.map { |x|
      Nokogiri::HTML(File.open(x)).at("body").inner_html
    }.join("\n")

    fdoc = Nokogiri::HTML(html)
    fdoc.search("h3").each do |h3|
      h3.name = "h4"
    end
    fdoc.search("h2").each do |h2|
      h2.name = "h3"
      h2["id"] = h2.inner_text.gsub(/\s/, "-")
    end
    add_head_section fdoc, "Front Matter"
    File.open("frontmatter.html", "w") { |f| f.puts fdoc.to_html }
    html_pages.unshift "frontmatter.html"
  end

  def generate_sections(html_pages)
    FileUtils::rm_rf("sections/")
    html_pages.each_with_index do |page, section_idx|
      FileUtils::mkdir_p("sections/%03d" % section_idx)
      doc = Nokogiri::HTML(File.open(page))
      title = doc.at("title").inner_text.gsub("Ruby on Rails Guides: ", "")
      title = page.capitalize.gsub(".html", "") if title.strip == ""
      File.open("sections/%03d/_section.txt" % section_idx, "w") { |f| f.puts title }
      doc.xpath("//h3[@id]").each_with_index do |h3, item_idx|
        subsection = h3.inner_text
        content = h3.xpath("./following-sibling::*").take_while { |x| x.name != "h3" }.map(&:to_html)
        item = Nokogiri::HTML(h3.to_html + content.join("\n"))
        item_path = "sections/%03d/%03d.html" % [section_idx, item_idx]
        add_head_section(item, subsection)
        item.search("img").each do |img|
          img["src"] = "#{Dir.pwd}/#{img['src']}"
        end
        item.xpath("//li/p").each { |p| p.swap(p.children); p.remove }
        File.open(item_path, "w") { |f| f.puts item.to_html }
      end
    end
  end

  def generate_document_metadata(mobi_outfile)
    puts "=> Generating _document.yml"
    x = Nokogiri::XML(File.open("rails_guides.opf")).remove_namespaces!
    cover_jpg = "#{Dir.pwd}/images/rails_guides_kindle_cover.jpg"
    cover_gif = cover_jpg.sub(/jpg$/, "gif")
    puts `convert #{cover_jpg} #{cover_gif}`
    document = {
      "doc_uuid" => x.at("package")["unique-identifier"],
      "title" => x.at("title").inner_text.gsub(/\(.*$/, " v2"),
      "publisher" => x.at("publisher").inner_text,
      "author" => x.at("creator").inner_text,
      "subject" => x.at("subject").inner_text,
      "date" => x.at("date").inner_text,
      "cover" => cover_gif,
      "masthead" => nil,
      "mobi_outfile" => mobi_outfile
    }
    puts document.to_yaml
    File.open("_document.yml", "w") { |f| f.puts document.to_yaml }
  end

  def add_head_section(doc, title)
    head = Nokogiri::XML::Node.new "head", doc
    title_node = Nokogiri::XML::Node.new "title", doc
    title_node.content = title
    title_node.parent = head
    css = Nokogiri::XML::Node.new "link", doc
    css["rel"] = "stylesheet"
    css["type"] = "text/css"
    css["href"] = "#{Dir.pwd}/stylesheets/kindle.css"
    css.parent = head
    doc.at("body").before head
  end
end
