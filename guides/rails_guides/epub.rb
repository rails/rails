#!/usr/bin/env ruby
# frozen_string_literal: true

require "nokogiri"
require "fileutils"
require "yaml"
require "date"

require "rails_guides/epub_packer"

module Epub # :nodoc:
  extend self

  def generate(output_dir, epub_outfile)
    fix_file_names(output_dir)
    generate_meta_files(output_dir)
    generate_epub(output_dir, epub_outfile)
  end

  private
    def open_toc_doc(toc)
      Nokogiri::XML(toc).xpath("//ncx:content", "ncx" => "http://www.daisy.org/z3986/2005/ncx/")
    end

    def generate_meta_files(output_dir)
      output_dir = File.absolute_path(File.join(output_dir, ".."))
      Dir.chdir output_dir do
        puts "=> Using output dir: #{output_dir}"
        puts "=> Generating meta files"
        FileUtils.mkdir_p("META-INF")
        File.write("META-INF/container.xml", <<~CONTENT)
        <?xml version="1.0" encoding="UTF-8"?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles>
              <rootfile full-path="OEBPS/rails_guides.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        CONTENT
      end
    end

    def generate_epub(output_dir, epub_outfile)
      output_dir = File.absolute_path(File.join(output_dir, ".."))
      Dir.chdir output_dir do
        puts "=> Generating EPUB"
        EpubPacker.pack("./", epub_outfile)
        puts "=> Done Generating EPUB"
      end
    end

    def is_name_invalid(name)
      name.match?(/\A\d/)
    end

    def fix_file_names(output_dir)
      book_dir = File.absolute_path(output_dir)
      Dir.chdir book_dir do
        puts "=> Using book dir: #{book_dir}"
        puts "=> Fixing filenames in Table of Contents"
        # opf file: item->id and itemref->idref attributes does not support values starting with a number
        toc = File.read("toc.ncx")
        toc_html = File.read("toc.html")
        opf = File.read("rails_guides.opf")

        doc = open_toc_doc(toc)
        doc.each do |c|
          name = c[:src]

          if is_name_invalid(name)
            FileUtils.mv(name, "rails_#{name}")
            toc.gsub!(name, "rails_#{name}")
            toc_html.gsub!(name, "rails_#{name}")
            opf.gsub!(name, "rails_#{name}")
          end
        end
        File.write("toc.ncx", toc)
        File.write("toc.html", toc_html)
        File.write("rails_guides.opf", opf)
      end
    end

    def add_head_section(doc, title)
      head = Nokogiri::XML::Node.new "head", doc
      title_node = Nokogiri::XML::Node.new "title", doc
      title_node.content = title
      title_node.parent = head
      css = Nokogiri::XML::Node.new "link", doc
      css["rel"] = "stylesheet"
      css["type"] = "text/css"
      css["href"] = "#{Dir.pwd}/stylesheets/epub.css"
      css.parent = head
      doc.at("body").before head
    end
end
