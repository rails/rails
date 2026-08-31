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
    replace_svgs_with_pngs(output_dir)
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

    def replace_svgs_with_pngs(output_dir)
      book_dir = File.absolute_path(output_dir)
      Dir.chdir book_dir do
        puts "=> Using book dir: #{book_dir}"
        puts "=> Replacing SVG images with PNGs"
        html_files = Dir.glob("**/*.html")
        html_files.each do |html_file|
          doc = Nokogiri::XML(File.read(html_file))
          images = doc.css("img")
          images.each do |img|
            src = img["src"]
            if src && File.extname(src).downcase == ".svg"
              replace_img_with_dark_light_mode_picture(img)
            end
          end
          File.write(html_file, doc.to_html)
        end
      end
    end

    # Detects if the img tag is wrapped around a picture tag
    # then replace the whole with new picture tag for dark/light mode support
    def replace_img_with_dark_light_mode_picture(img_tag_node)
      img_src = img_tag_node["src"]
      return unless img_src

      image_name = File.basename(img_src, ".svg")

      new_picture_tag = Nokogiri::XML::Node.new "picture", img_tag_node.document

      img_path = File.dirname(img_src)

      file_path = "#{img_path}/#{image_name}-dark.png"
      dark_added = add_pic_node(new_picture_tag, img_tag_node, file_path, "source")

      file_path = "#{img_path}/#{image_name}-light.png"
      light_added = add_pic_node(new_picture_tag, img_tag_node, file_path, "img")

      alternate_added = if !dark_added && !light_added
        alternate_path = "#{img_path}/#{image_name}.png"
        add_pic_node(new_picture_tag, img_tag_node, alternate_path, "img")
      end

      parent = img_tag_node.parent

      return if !dark_added && !light_added && !alternate_added

      if parent.name == "picture"
        parent.replace(new_picture_tag)
      else
        img_tag_node.replace(new_picture_tag)
      end
    end

    def add_pic_node(new_picture_tag, img_tag_node, img_path, tag_name)
      return false unless File.exist?(img_path)

      new_tag = Nokogiri::XML::Node.new tag_name, img_tag_node.document
      new_tag[tag_name == "source" ? "srcset" : "src"] = img_path
      new_tag["media"] = "(prefers-color-scheme: dark)" if tag_name == "source"
      new_tag["alt"] = img_tag_node["alt"] || ""
      new_picture_tag.add_child(new_tag)
    end
end
