require 'abstract_unit'

class TemplateFileTest < Test::Unit::TestCase
  LOAD_PATH_ROOT = File.join(File.dirname(__FILE__), '..', 'fixtures')

  def setup
    @template = ActionView::TemplateFile.new("test/hello_world.html.erb")
    @another_template = ActionView::TemplateFile.new("test/hello_world.erb")
    @file_only = ActionView::TemplateFile.new("hello_world.erb")
    @full_path = ActionView::TemplateFile.new("/u/app/scales/config/../app/views/test/hello_world.erb", true)
    @layout = ActionView::TemplateFile.new("layouts/hello")
    @multipart = ActionView::TemplateFile.new("test_mailer/implicitly_multipart_example.text.html.erb")
  end

  def test_path
    assert_equal "test/hello_world.html.erb", @template.path
    assert_equal "test/hello_world.erb", @another_template.path
    assert_equal "hello_world.erb", @file_only.path
    assert_equal "/u/app/scales/config/../app/views/test/hello_world.erb", @full_path.path
    assert_equal "layouts/hello", @layout.path
    assert_equal "test_mailer/implicitly_multipart_example.text.html.erb", @multipart.path
  end

  def test_path_without_extension
    assert_equal "test/hello_world.html", @template.path_without_extension
    assert_equal "test/hello_world", @another_template.path_without_extension
    assert_equal "hello_world", @file_only.path_without_extension
    assert_equal "layouts/hello", @layout.path_without_extension
    assert_equal "test_mailer/implicitly_multipart_example.text.html", @multipart.path_without_extension
  end

  def test_path_without_format_and_extension
    assert_equal "test/hello_world", @template.path_without_format_and_extension
    assert_equal "test/hello_world", @another_template.path_without_format_and_extension
    assert_equal "hello_world", @file_only.path_without_format_and_extension
    assert_equal "layouts/hello", @layout.path_without_format_and_extension
    assert_equal "test_mailer/implicitly_multipart_example", @multipart.path_without_format_and_extension
  end

  def test_name
    assert_equal "hello_world", @template.name
    assert_equal "hello_world", @another_template.name
    assert_equal "hello_world", @file_only.name
    assert_equal "hello_world", @full_path.name
    assert_equal "hello", @layout.name
    assert_equal "implicitly_multipart_example", @multipart.name
  end

  def test_format
    assert_equal "html", @template.format
    assert_equal nil, @another_template.format
    assert_equal nil, @layout.format
    assert_equal "text.html", @multipart.format
  end

  def test_extension
    assert_equal "erb", @template.extension
    assert_equal "erb", @another_template.extension
    assert_equal nil, @layout.extension
    assert_equal "erb", @multipart.extension
  end

  def test_format_and_extension
    assert_equal "html.erb", @template.format_and_extension
    assert_equal "erb", @another_template.format_and_extension
    assert_equal nil, @layout.format_and_extension
    assert_equal "text.html.erb", @multipart.format_and_extension
  end

  def test_new_file_with_extension
    file = @template.dup_with_extension(:haml)
    assert_equal "test/hello_world.html", file.path_without_extension
    assert_equal "haml", file.extension
    assert_equal "test/hello_world.html.haml", file.path

    file = @another_template.dup_with_extension(:haml)
    assert_equal "test/hello_world", file.path_without_extension
    assert_equal "haml", file.extension
    assert_equal "test/hello_world.haml", file.path

    file = @another_template.dup_with_extension(nil)
    assert_equal "test/hello_world", file.path_without_extension
    assert_equal nil, file.extension
    assert_equal "test/hello_world", file.path
  end

  def test_freezes_entire_contents
    @template.freeze
    assert @template.frozen?
    assert @template.base_path.frozen?
    assert @template.name.frozen?
    assert @template.format.frozen?
    assert @template.extension.frozen?
  end
end
