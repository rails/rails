require 'abstract_unit'
require 'controller/fake_models'

class ViewRenderTest < Test::Unit::TestCase
  def setup
    @assigns = { :secret => 'in the sauce' }
    @view = ActionView::Base.new(ActionController::Base.view_paths, @assigns)
  end

  def test_render_file
    assert_deprecated do
      assert_equal "Hello world!", @view.render("test/hello_world.erb")
    end
  end

  def test_render_file_not_using_full_path
    assert_equal "Hello world!", @view.render(:file => "test/hello_world.erb")
  end

  def test_render_file_without_specific_extension
    assert_deprecated do
      assert_equal "Hello world!", @view.render("test/hello_world")
    end
  end

  def test_render_file_at_top_level
    assert_deprecated do
      assert_equal 'Elastica', @view.render('/shared')
    end
  end

  def test_render_file_with_full_path
    template_path = File.join(File.dirname(__FILE__), '../fixtures/test/hello_world.erb')
    assert_equal "Hello world!", @view.render(:file => template_path)
  end

  def test_render_file_with_instance_variables
    assert_deprecated do
      assert_equal "The secret is in the sauce\n", @view.render("test/render_file_with_ivar.erb")
    end
  end

  def test_render_file_with_locals
    locals = { :secret => 'in the sauce' }
    assert_deprecated do
      assert_equal "The secret is in the sauce\n", @view.render("test/render_file_with_locals.erb", locals)
    end
  end

  def test_render_file_not_using_full_path_with_dot_in_path
    assert_deprecated do
      assert_equal "The secret is in the sauce\n", @view.render("test/dot.directory/render_file_with_ivar")
    end
  end

  def test_render_has_access_current_template
    assert_deprecated do
      assert_equal "test/template.erb", @view.render("test/template.erb")
    end
  end

  def test_render_update
    # TODO: You should not have to stub out template because template is self!
    @view.instance_variable_set(:@template, @view)
    assert_equal 'alert("Hello, World!");', @view.render(:update) { |page| page.alert('Hello, World!') }
  end

  def test_render_partial
    assert_equal "only partial", @view.render(:partial => "test/partial_only")
  end

  def test_render_partial_with_format
    assert_equal 'partial html', @view.render(:partial => 'test/partial')
  end

  def test_render_partial_at_top_level
    # file fixtures/_top_level_partial_only.erb (not fixtures/test)
    assert_equal 'top level partial', @view.render(:partial => '/top_level_partial_only')
  end

  def test_render_partial_with_format_at_top_level
    # file fixtures/_top_level_partial.html.erb (not fixtures/test, with format extension)
    assert_equal 'top level partial html', @view.render(:partial => '/top_level_partial')
  end

  def test_render_partial_with_locals
    assert_equal "5", @view.render(:partial => "test/counter", :locals => { :counter_counter => 5 })
  end

  def test_render_partial_with_errors
    @view.render(:partial => "test/raise")
    flunk "Render did not raise TemplateError"
  rescue ActionView::TemplateError => e
    assert_match "undefined local variable or method `doesnt_exist'", e.message
    assert_equal "", e.sub_template_message
    assert_equal "1", e.line_number
    assert_equal File.expand_path("#{FIXTURE_LOAD_PATH}/test/_raise.html.erb"), e.file_name
  end

  def test_render_sub_template_with_errors
    @view.render(:file => "test/sub_template_raise")
    flunk "Render did not raise TemplateError"
  rescue ActionView::TemplateError => e
    assert_match "undefined local variable or method `doesnt_exist'", e.message
    assert_equal "Trace of template inclusion: #{File.expand_path("#{FIXTURE_LOAD_PATH}/test/sub_template_raise.html.erb")}", e.sub_template_message
    assert_equal "1", e.line_number
    assert_equal File.expand_path("#{FIXTURE_LOAD_PATH}/test/_raise.html.erb"), e.file_name
  end

  def test_render_partial_collection
    assert_equal "Hello: davidHello: mary", @view.render(:partial => "test/customer", :collection => [ Customer.new("david"), Customer.new("mary") ])
  end

  def test_render_partial_collection_as
    assert_equal "david david davidmary mary mary",
      @view.render(:partial => "test/customer_with_var", :collection => [ Customer.new("david"), Customer.new("mary") ], :as => :customer)
  end

  def test_render_partial_collection_without_as
    assert_equal "local_inspector,local_inspector_counter,object",
      @view.render(:partial => "test/local_inspector", :collection => [ Customer.new("mary") ])
  end

  def test_render_partial_with_empty_collection_should_return_nil
    assert_nil @view.render(:partial => "test/customer", :collection => [])
  end

  def test_render_partial_with_nil_collection_should_return_nil
    assert_nil @view.render(:partial => "test/customer", :collection => nil)
  end

  def test_render_partial_with_nil_values_in_collection
    assert_equal "Hello: davidHello: Anonymous", @view.render(:partial => "test/customer", :collection => [ Customer.new("david"), nil ])
  end

  def test_render_partial_with_empty_array_should_return_nil
    assert_nil @view.render(:partial => [])
  end

  # TODO: The reason for this test is unclear, improve documentation
  def test_render_partial_and_fallback_to_layout
    assert_equal "Before (Josh)\n\nAfter", @view.render(:partial => "test/layout_for_partial", :locals => { :name => "Josh" })
  end

  # TODO: The reason for this test is unclear, improve documentation
  def test_render_js_partial_and_fallback_to_erb_layout
    @view.template_format = :js
    assert_equal "Before (Josh)\n\nAfter", @view.render(:partial => "test/layout_for_partial", :locals => { :name => "Josh" })
  end

  # TODO: The reason for this test is unclear, improve documentation
  def test_render_missing_xml_partial_and_raise_missing_template
    @view.template_format = :xml
    assert_raise(ActionView::MissingTemplate) { @view.render(:partial => "test/layout_for_partial") }
  end

  def test_render_inline
    assert_equal "Hello, World!", @view.render(:inline => "Hello, World!")
  end

  def test_render_inline_with_locals
    assert_equal "Hello, Josh!", @view.render(:inline => "Hello, <%= name %>!", :locals => { :name => "Josh" })
  end

  def test_render_fallbacks_to_erb_for_unknown_types
    assert_equal "Hello, World!", @view.render(:inline => "Hello, World!", :type => :foo)
  end

  CustomHandler = lambda do |template|
    "@output_buffer = ''\n" +
      "@output_buffer << 'source: #{template.source.inspect}'\n"
  end

  def test_render_inline_with_compilable_custom_type
    ActionView::Template.register_template_handler :foo, CustomHandler
    assert_equal 'source: "Hello, World!"', @view.render(:inline => "Hello, World!", :type => :foo)
  end

  def test_render_inline_with_locals_and_compilable_custom_type
    ActionView::Template.register_template_handler :foo, CustomHandler
    assert_equal 'source: "Hello, <%= name %>!"', @view.render(:inline => "Hello, <%= name %>!", :locals => { :name => "Josh" }, :type => :foo)
  end

  def test_render_with_layout
    assert_equal %(<title></title>\nHello world!\n),
      @view.render(:file => "test/hello_world.erb", :layout => "layouts/yield")
  end

  def test_render_with_nested_layout
    assert_equal %(<title>title</title>\n<div id="column">column</div>\n<div id="content">content</div>\n),
      @view.render(:file => "test/nested_layout.erb", :layout => "layouts/yield")
  end
end
