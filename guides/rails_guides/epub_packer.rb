#!/usr/bin/env ruby
# frozen_string_literal: true

require "nokogiri"
require "fileutils"
require "yaml"
require "date"
require "zip"

module EpubPacker # :nodoc:
  extend self

  def pack(output_dir, epub_file_name)
    @output_dir = output_dir

    FileUtils.rm_f(epub_file_name)

    Zip::OutputStream.open(epub_file_name) {
      |epub|
      create_epub(epub, epub_file_name)
    }

    entries = Dir.entries(output_dir) - %w[. ..]

    entries.reject! { |item| File.extname(item) == ".epub" }

    Zip::File.open(epub_file_name, create: true) do |epub|
      write_entries(entries, "", epub)
    end
  end

  def create_epub(epub, epub_file_name)
    epub.put_next_entry("mimetype", nil, nil, Zip::Entry::STORED, Zlib::NO_COMPRESSION)
    epub.write "application/epub+zip"
  end

  def write_entries(entries, path, zipfile)
    entries.each do |e|
      zipfile_path = path == "" ? e : File.join(path, e)
      disk_file_path = File.join(@output_dir, zipfile_path)

      if File.directory? disk_file_path
        recursively_deflate_directory(disk_file_path, zipfile, zipfile_path)
      else
        put_into_archive(disk_file_path, zipfile, zipfile_path)
      end
    end
  end

  def recursively_deflate_directory(disk_file_path, zipfile, zipfile_path)
    zipfile.mkdir zipfile_path
    subdir = Dir.entries(disk_file_path) - %w[. ..]
    write_entries subdir, zipfile_path, zipfile
  end

  def put_into_archive(disk_file_path, zipfile, zipfile_path)
    zipfile.add(zipfile_path, disk_file_path)
  end
end
