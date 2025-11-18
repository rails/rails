# frozen_string_literal: true

require "test_helper"

class EpubTest < ActiveSupport::TestCase
  def setup
    @path = Dir.mktmpdir
    Dir.chdir(@path)
    @html_file = File.join(@path, "test.html")
    @alternate_png_file = "images/sample.png"
    File.write(@html_file, <<~HTML)
      <html>
        <body>
          <img src="images/sample.svg" alt="Sample Image"/>
        </body>
      </html>
    HTML
  end

  def teardown
    FileUtils.remove_entry(@path)
  end

  def test_replace_svgs_with_pngs_when_variants_exist
    FileUtils.mkdir_p(File.join(@path, "images"))
    File.write(File.join(@path, "images", "sample-light.png"), "")
    File.write(File.join(@path, "images", "sample-dark.png"), "")

    Epub.send(:replace_svgs_with_pngs, @path)

    result = File.read(@html_file)
    assert_includes result, "<picture>"
    assert_includes result, %Q{<source srcset="images/sample-dark.png" media="(prefers-color-scheme: dark)}
    assert_includes result, %Q{<img src="images/sample-light.png" alt="Sample Image">}
  end

  def test_replace_svgs_with_alternate_pngs_when_no_variants_exist
    FileUtils.mkdir_p(File.join(@path, "images"))
    File.write(File.join(@path, @alternate_png_file), "")

    Epub.send(:replace_svgs_with_pngs, @path)

    result = File.read(@html_file)
    assert_includes result, "<picture>"
    assert_includes result, "images/sample.png"
  end

  def test_do_not_replace_svgs_with_pngs_when_no_variants_exist
    Epub.send(:replace_svgs_with_pngs, @path)

    result = File.read(@html_file)
    assert_not_includes result, "<picture>"
    assert_includes result, "images/sample.svg"
    assert_not_includes result, "sample-dark.png"
  end
end
