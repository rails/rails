#!/usr/bin/env ruby

unless `which kindlerb` 
  abort "Please gem install kindlerb"
end

require 'nokogiri'
require 'fileutils'
require 'yaml'
require 'date'

module Kindle
  extend self

  def generate(output_dir, outfile)

    Dir.chdir output_dir do 

      # Get html pages in document order
      toc = File.read("toc.ncx")
      #puts toc
      # <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" xml:lang="en-US">
      doc = Nokogiri::XML(toc).xpath("//ncx:content", 'ncx' => "http://www.daisy.org/z3986/2005/ncx/")
      html_pages = doc.select {|c| c[:src]}.map {|c| c[:src]}.uniq
      puts html_pages

      frontmatter = []

      html_pages.delete_if {|x| 
        # we need to treat frontmatter differently
        if x =~ /(toc|welcome|credits|copyright).html/
          frontmatter << x unless x =~ /toc/
          true
        end

      }

      puts "=> Making one section for all frontmatter."
      html = frontmatter.map {|x|
        Nokogiri::HTML(File.open(x)).at("body").inner_html
      }.join("\n")

      fdoc = Nokogiri::HTML(html)

      # need to turn author h3's into h4's
      fdoc.search("h3").each { |h3|
        h3.name = 'h4'
      }
      fdoc.search("h2").each { |h2| 
        h2.name = 'h3'
        h2['id'] = h2.inner_text.gsub(/\s/, '-')
      }

      add_head_section fdoc, "Frontmatter"
      File.open("frontmatter.html",'w'){|f| f.puts fdoc.to_html}
      html_pages.unshift "frontmatter.html"

      puts "=> Making one section folder per original HTML file"
      FileUtils::rm_rf("sections/")

      html_pages.each_with_index { |page, section_idx|
        FileUtils::mkdir_p("sections/%03d" % section_idx)
        doc = Nokogiri::HTML(File.open(page))
        title = doc.at("title").inner_text.gsub("Ruby on Rails Guides: ", '')
        title = page.capitalize.gsub('.html', '') if title.strip == ''
        File.open("sections/%03d/_section.txt" % section_idx, 'w') {|f| f.puts title}
        puts "sections/%03d -> #{title}" % section_idx
        
        # Fragment the page file into subsections
        doc.xpath("//h3[@id]").each_with_index { |h3,item_idx|
          subsection = h3.inner_text
          content = h3.xpath("./following-sibling::*").take_while {|x| x.name != "h3"}.map {|x| x.to_html}
          item = Nokogiri::HTML(h3.to_html + content.join("\n"))
          item_path = "sections/%03d/%03d.html" % [section_idx, item_idx] 

          add_head_section item, subsection

          # fix all image links
          item.search("img").each { |img|
            img['src'] = "#{Dir.pwd}/#{img['src']}"
          }


          File.open(item_path, 'w'){|f| f.puts item.to_html}
          puts "  #{item_path} -> #{subsection}"

        }
      }

      puts "=> Generating _document.yml"


      x = Nokogiri::XML(File.open("rails_guides.opf")).remove_namespaces!

      document = {
        'doc_uuid' => x.at("package")['unique-identifier'],
        'title' => x.at("title").inner_text.gsub(/\(.*$/, " v2"),
        'publisher' => x.at("publisher").inner_text,
        'author' => x.at("creator").inner_text,
        'subject' => x.at("subject").inner_text,
        'date' => x.at("date").inner_text,
        'cover' => "#{Dir.pwd}/images/rails_guides_kindle_cover.jpg", 
        'masthead' => nil,
        'mobi_outfile' => outfile
      }
      puts document.inspect
      File.open("_document.yml", 'w'){|f| f.puts document.to_yaml}

      exec "kindlerb ."
    end
  end

  def add_head_section(doc, title)
    head = Nokogiri::XML::Node.new "head", doc
    title_node = Nokogiri::XML::Node.new "title", doc
    title_node.content = title
    title_node.parent = head
    css = Nokogiri::XML::Node.new "link", doc
    css['rel'] = 'stylesheet'
    css['type'] = 'text/css'
    css['href'] = "#{Dir.pwd}/stylesheets/kindle.css"
    css.parent = head
    doc.at("body").before head
  end

end
