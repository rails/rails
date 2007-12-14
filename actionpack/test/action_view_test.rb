require File.dirname(__FILE__) + '/abstract_unit'
require 'test/unit'

class ActionViewTests < Test::Unit::TestCase
  def test_find_template_extension_from_first_render
    base = ActionView::Base.new

    assert_nil base.send(:find_template_extension_from_first_render)

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
      base.instance_variable_set('@first_render', input)
      assert_equal expectation, base.send(:find_template_extension_from_first_render)
    end
  end
  
  def test_should_report_file_exists_correctly
    base = ActionView::Base.new

    assert_nil base.send(:find_template_extension_from_first_render)
    
    assert_equal false, base.send(:file_exists?, 'test.rhtml')
    assert_equal false, base.send(:file_exists?, 'test.rb')

    base.instance_variable_set('@first_render', 'foo.rb')
    
    assert_equal 'rb', base.send(:find_template_extension_from_first_render)
    
    assert_equal false, base.send(:file_exists?, 'baz')
    assert_equal false, base.send(:file_exists?, 'baz.rb')

  end
  
end
