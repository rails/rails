require "#{File.dirname(__FILE__)}/../abstract_unit"
require "#{File.dirname(__FILE__)}/../testing_sandbox"

class ActionViewTemplateTest < Test::Unit::TestCase
  include TestingSandbox
  
  uses_mocha "Action View Templates" do
    def setup
      @template = ActionView::Base.new
    end
    
    def test_should_find_delegated_extension
      @template.expects(:delegate_template_exists?).with('foo').returns(['foo'])
      assert_equal :foo, @template.send(:find_template_extension_for, 'foo')
    end
    
    def test_should_find_formatted_erb_extension
      @template.expects(:delegate_template_exists?).with('foo').returns(nil)
      @template.expects(:formatted_template_exists?).with('foo.html').returns("erb")
      assert_equal "html.erb", @template.send(:find_template_extension_for, 'foo')
    end
    
    def test_should_find_erb_extension
      @template.expects(:delegate_template_exists?).with('foo').returns(nil)
      @template.expects(:formatted_template_exists?).with('foo.html').returns(nil)
      @template.expects(:erb_template_exists?).with('foo').returns(:erb)
      assert_equal :erb, @template.send(:find_template_extension_for, 'foo')
    end
    
    def test_should_find_builder_extension
      @template.expects(:delegate_template_exists?).with('foo').returns(nil)
      @template.expects(:formatted_template_exists?).with('foo.html').returns(nil)
      @template.expects(:erb_template_exists?).with('foo').returns(nil)
      @template.expects(:builder_template_exists?).with('foo').returns(:builder)
      assert_equal :builder, @template.send(:find_template_extension_for, 'foo')
    end
    
    def test_should_find_javascript_extension
      @template.expects(:delegate_template_exists?).with('foo').returns(nil)
      @template.expects(:formatted_template_exists?).with('foo.html').returns(nil)
      @template.expects(:erb_template_exists?).with('foo').returns(nil)
      @template.expects(:builder_template_exists?).with('foo').returns(nil)
      @template.expects(:javascript_template_exists?).with('foo').returns(true)
      assert_equal :rjs, @template.send(:find_template_extension_for, 'foo')
    end
  end
end