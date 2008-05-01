require 'abstract_unit'

class TemplateFinderTest < Test::Unit::TestCase

  LOAD_PATH_ROOT = File.join(File.dirname(__FILE__), '..', 'fixtures')

  def setup
    ActionView::TemplateFinder.process_view_paths(LOAD_PATH_ROOT)
    ActionView::Template::register_template_handler :mab, Class.new(ActionView::TemplateHandler)
    @template = ActionView::Base.new
    @finder = ActionView::TemplateFinder.new(@template, LOAD_PATH_ROOT)
  end

  def test_should_raise_exception_for_unprocessed_view_path
    assert_raises ActionView::TemplateFinder::InvalidViewPath do
      ActionView::TemplateFinder.new(@template, File.dirname(__FILE__))
    end
  end

  def test_should_cache_file_extension_properly
    assert_equal ["builder", "erb", "rhtml", "rjs", "rxml", "mab"].sort,
                 ActionView::TemplateFinder.file_extension_cache[LOAD_PATH_ROOT].values.flatten.uniq.sort

    assert_equal (Dir.glob("#{LOAD_PATH_ROOT}/**/*/*.{erb,rjs,rhtml,builder,rxml,mab}") |
                  Dir.glob("#{LOAD_PATH_ROOT}/**.{erb,rjs,rhtml,builder,rxml,mab}")).size,
                 ActionView::TemplateFinder.file_extension_cache[LOAD_PATH_ROOT].keys.size
  end

  def test_should_cache_dir_content_properly
    assert ActionView::TemplateFinder.processed_view_paths[LOAD_PATH_ROOT]
    assert_equal (Dir.glob("#{LOAD_PATH_ROOT}/**/*/**") | Dir.glob("#{LOAD_PATH_ROOT}/**")).find_all {|f| !File.directory?(f) }.size,
               ActionView::TemplateFinder.processed_view_paths[LOAD_PATH_ROOT].size
  end

  def test_find_template_extension_from_first_render
    assert_nil @finder.send(:find_template_extension_from_first_render)

    {
      nil => nil,
      '' => nil,
      'foo' => nil,
      '/foo' => nil,
      'foo.rb' => 'rb',
      'foo.bar.rb' => 'bar.rb',
      'baz/foo.rb' => 'rb',
      'baz/foo.bar.rb' => 'bar.rb',
      'baz/foo.o/foo.rb' => 'rb',
      'baz/foo.o/foo.bar.rb' => 'bar.rb',
    }.each do |input,expectation|
      @template.instance_variable_set('@first_render', input)
      assert_equal expectation, @finder.send(:find_template_extension_from_first_render)
    end
  end

  def test_should_report_file_exists_correctly
    assert_nil @finder.send(:find_template_extension_from_first_render)
    assert_equal false, @finder.send(:file_exists?, 'test.rhtml')
    assert_equal false, @finder.send(:file_exists?, 'test.rb')

    @template.instance_variable_set('@first_render', 'foo.rb')

    assert_equal 'rb', @finder.send(:find_template_extension_from_first_render)
    assert_equal false, @finder.send(:file_exists?, 'baz')
    assert_equal false, @finder.send(:file_exists?, 'baz.rb')
  end
  
  uses_mocha 'Template finder tests' do
    def test_should_update_extension_cache_when_template_handler_is_registered
      ActionView::TemplateFinder.expects(:update_extension_cache_for).with("funky")
      ActionView::Template::register_template_handler :funky, Class.new(ActionView::TemplateHandler)
    end
  end
end
