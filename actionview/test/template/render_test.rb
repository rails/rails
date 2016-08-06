require "abstract_unit"
require "controller/fake_models"

class TestController < ActionController::Base
end

module RenderTestCases
  def setup_view(paths)
    @assigns = { :secret => "in the sauce" }
    @view = Class.new(ActionView::Base) do
      def view_cache_dependencies; end

      def fragment_cache_key(key)
        ActiveSupport::Cache.expand_cache_key(key, :views)
      end
    end.new(paths, @assigns)

    @controller_view = TestController.new.view_context

    # Reload and register danish language for testing
    I18n.backend.store_translations "da", {}
    I18n.backend.store_translations "pt-BR", {}

    # Ensure original are still the same since we are reindexing view paths
    assert_equal ORIGINAL_LOCALES, I18n.available_locales.map(&:to_s).sort
  end

  def test_render_without_options
    e = assert_raises(ArgumentError) { @view.render() }
    assert_match(/You invoked render but did not give any of (.+) option./, e.message)
  end

  def test_render_file
    assert_equal "Hello world!", @view.render(:file => "test/hello_world")
  end

  # Test if :formats, :locale etc. options are passed correctly to the resolvers.
  def test_render_file_with_format
    assert_match "<h1>No Comment</h1>", @view.render(:file => "comments/empty", :formats => [:html])
    assert_match "<error>No Comment</error>", @view.render(:file => "comments/empty", :formats => [:xml])
    assert_match "<error>No Comment</error>", @view.render(:file => "comments/empty", :formats => :xml)
  end

  def test_render_template_with_format
    assert_match "<h1>No Comment</h1>", @view.render(:template => "comments/empty", :formats => [:html])
    assert_match "<error>No Comment</error>", @view.render(:template => "comments/empty", :formats => [:xml])
  end

  def test_rendered_format_without_format
    @view.render(:inline => "test")
    assert_equal :html, @view.lookup_context.rendered_format
  end

  def test_render_partial_implicitly_use_format_of_the_rendered_template
    @view.lookup_context.formats = [:json]
    assert_equal "Hello world", @view.render(:template => "test/one", :formats => [:html])
  end

  def test_render_partial_implicitly_use_format_of_the_rendered_partial
    @view.lookup_context.formats = [:html]
    assert_equal "Third level", @view.render(:template => "test/html_template")
  end

  def test_render_partial_use_last_prepended_format_for_partials_with_the_same_names
    @view.lookup_context.formats = [:html]
    assert_equal "\nHTML Template, but JSON partial", @view.render(:template => "test/change_priority")
  end

  def test_render_template_with_a_missing_partial_of_another_format
    @view.lookup_context.formats = [:html]
    e = assert_raise ActionView::Template::Error do
      @view.render(:template => "with_format", :formats => [:json])
    end
    assert_includes(e.message, "Missing partial /_missing with {:locale=>[:en], :formats=>[:json], :variants=>[], :handlers=>[:raw, :erb, :html, :builder, :ruby]}.")
  end

  def test_render_file_with_locale
    assert_equal "<h1>Kein Kommentar</h1>", @view.render(:file => "comments/empty", :locale => [:de])
    assert_equal "<h1>Kein Kommentar</h1>", @view.render(:file => "comments/empty", :locale => :de)
  end

  def test_render_template_with_locale
    assert_equal "<h1>Kein Kommentar</h1>", @view.render(:template => "comments/empty", :locale => [:de])
  end

  def test_render_file_with_handlers
    assert_equal "<h1>No Comment</h1>\n", @view.render(:file => "comments/empty", :handlers => [:builder])
    assert_equal "<h1>No Comment</h1>\n", @view.render(:file => "comments/empty", :handlers => :builder)
  end

  def test_render_template_with_handlers
    assert_equal "<h1>No Comment</h1>\n", @view.render(:template => "comments/empty", :handlers => [:builder])
  end

  def test_render_raw_template_with_handlers
    assert_equal "<%= hello_world %>\n", @view.render(:template => "plain_text")
  end

  def test_render_raw_template_with_quotes
    assert_equal %q;Here are some characters: !@#$%^&*()-="'}{`; + "\n", @view.render(:template => "plain_text_with_characters")
  end

  def test_render_raw_is_html_safe_and_does_not_escape_output
    buffer = ActiveSupport::SafeBuffer.new
    buffer << @view.render(file: "plain_text")
    assert_equal true, buffer.html_safe?
    assert_equal buffer, "<%= hello_world %>\n"
  end

  def test_render_ruby_template_with_handlers
    assert_equal "Hello from Ruby code", @view.render(:template => "ruby_template")
  end

  def test_render_ruby_template_inline
    assert_equal "4", @view.render(:inline => "(2**2).to_s", :type => :ruby)
  end

  def test_render_file_with_localization_on_context_level
    old_locale, @view.locale = @view.locale, :da
    assert_equal "Hey verden", @view.render(:file => "test/hello_world")
  ensure
    @view.locale = old_locale
  end

  def test_render_file_with_dashed_locale
    old_locale, @view.locale = @view.locale, :"pt-BR"
    assert_equal "Ola mundo", @view.render(:file => "test/hello_world")
  ensure
    @view.locale = old_locale
  end

  def test_render_file_at_top_level
    assert_equal "Elastica", @view.render(:file => "/shared")
  end

  def test_render_file_with_full_path
    template_path = File.join(File.dirname(__FILE__), "../fixtures/test/hello_world")
    assert_equal "Hello world!", @view.render(:file => template_path)
  end

  def test_render_file_with_instance_variables
    assert_equal "The secret is in the sauce\n", @view.render(:file => "test/render_file_with_ivar")
  end

  def test_render_file_with_locals
    locals = { :secret => "in the sauce" }
    assert_equal "The secret is in the sauce\n", @view.render(:file => "test/render_file_with_locals", :locals => locals)
  end

  def test_render_file_not_using_full_path_with_dot_in_path
    assert_equal "The secret is in the sauce\n", @view.render(:file => "test/dot.directory/render_file_with_ivar")
  end

  def test_render_partial_from_default
    assert_equal "only partial", @view.render("test/partial_only")
  end

  def test_render_outside_path
    assert File.exist?(File.join(File.dirname(__FILE__), "../../test/abstract_unit.rb"))
    assert_raises ActionView::MissingTemplate do
      @view.render(:template => "../\\../test/abstract_unit.rb")
    end
  end

  def test_render_partial
    assert_equal "only partial", @view.render(:partial => "test/partial_only")
  end

  def test_render_partial_with_format
    assert_equal "partial html", @view.render(:partial => "test/partial")
  end

  def test_render_partial_with_selected_format
    assert_equal "partial html", @view.render(:partial => "test/partial", :formats => :html)
    assert_equal "partial js", @view.render(:partial => "test/partial", :formats => [:js])
  end

  def test_render_partial_at_top_level
    # file fixtures/_top_level_partial_only (not fixtures/test)
    assert_equal "top level partial", @view.render(:partial => "/top_level_partial_only")
  end

  def test_render_partial_with_format_at_top_level
    # file fixtures/_top_level_partial.html (not fixtures/test, with format extension)
    assert_equal "top level partial html", @view.render(:partial => "/top_level_partial")
  end

  def test_render_partial_with_locals
    assert_equal "5", @view.render(:partial => "test/counter", :locals => { :counter_counter => 5 })
  end

  def test_render_partial_with_locals_from_default
    assert_equal "only partial", @view.render("test/partial_only", :counter_counter => 5)
  end

  def test_render_partial_with_number
    assert_nothing_raised { @view.render(:partial => "test/200") }
  end

  def test_render_partial_with_missing_filename
    assert_raises(ActionView::MissingTemplate) { @view.render(:partial => "test/") }
  end

  def test_render_partial_with_incompatible_object
    e = assert_raises(ArgumentError) { @view.render(:partial => nil) }
    assert_equal "'#{nil.inspect}' is not an ActiveModel-compatible object. It must implement :to_partial_path.", e.message
  end

  def test_render_partial_starting_with_a_capital
    assert_nothing_raised { @view.render(:partial => "test/FooBar") }
  end

  def test_render_partial_with_hyphen
    assert_nothing_raised { @view.render(:partial => "test/a-in") }
  end

  def test_render_partial_with_unicode_text
    assert_nothing_raised { @view.render(:partial => "test/🍣") }
  end

  def test_render_partial_with_invalid_option_as
    e = assert_raises(ArgumentError) { @view.render(:partial => "test/partial_only", :as => "a-in") }
    assert_equal "The value (a-in) of the option `as` is not a valid Ruby identifier; " +
      "make sure it starts with lowercase letter, " +
      "and is followed by any combination of letters, numbers and underscores.", e.message
  end

  def test_render_partial_with_hyphen_and_invalid_option_as
    e = assert_raises(ArgumentError) { @view.render(:partial => "test/a-in", :as => "a-in") }
    assert_equal "The value (a-in) of the option `as` is not a valid Ruby identifier; " +
      "make sure it starts with lowercase letter, " +
      "and is followed by any combination of letters, numbers and underscores.", e.message
  end

  def test_render_partial_with_errors
    e = assert_raises(ActionView::Template::Error) { @view.render(:partial => "test/raise") }
    assert_match %r!method.*doesnt_exist!, e.message
    assert_equal "", e.sub_template_message
    assert_equal "1", e.line_number
    assert_equal "1: <%= doesnt_exist %>", e.annoted_source_code[0].strip
    assert_equal File.expand_path("#{FIXTURE_LOAD_PATH}/test/_raise.html.erb"), e.file_name
  end

  def test_render_error_indentation
    e = assert_raises(ActionView::Template::Error) { @view.render(:partial => "test/raise_indentation") }
    error_lines = e.annoted_source_code
    assert_match %r!error\shere!, e.message
    assert_equal "11", e.line_number
    assert_equal "     9: <p>Ninth paragraph</p>", error_lines.second
    assert_equal "    10: <p>Tenth paragraph</p>", error_lines.third
  end

  def test_render_sub_template_with_errors
    e = assert_raises(ActionView::Template::Error) { @view.render(:template => "test/sub_template_raise") }
    assert_match %r!method.*doesnt_exist!, e.message
    assert_equal "Trace of template inclusion: #{File.expand_path("#{FIXTURE_LOAD_PATH}/test/sub_template_raise.html.erb")}", e.sub_template_message
    assert_equal "1", e.line_number
    assert_equal File.expand_path("#{FIXTURE_LOAD_PATH}/test/_raise.html.erb"), e.file_name
  end

  def test_render_file_with_errors
    e = assert_raises(ActionView::Template::Error) { @view.render(:file => File.expand_path("test/_raise", FIXTURE_LOAD_PATH)) }
    assert_match %r!method.*doesnt_exist!, e.message
    assert_equal "", e.sub_template_message
    assert_equal "1", e.line_number
    assert_equal "1: <%= doesnt_exist %>", e.annoted_source_code[0].strip
    assert_equal File.expand_path("#{FIXTURE_LOAD_PATH}/test/_raise.html.erb"), e.file_name
  end

  def test_render_object
    assert_equal "Hello: david", @view.render(:partial => "test/customer", :object => Customer.new("david"))
    assert_equal "FalseClass", @view.render(:partial => "test/klass", :object => false)
    assert_equal "NilClass", @view.render(:partial => "test/klass", :object => nil)
  end

  def test_render_object_with_array
    assert_equal "[1, 2, 3]", @view.render(:partial => "test/object_inspector", :object => [1, 2, 3])
  end

  def test_render_partial_collection
    assert_equal "Hello: davidHello: mary", @view.render(:partial => "test/customer", :collection => [ Customer.new("david"), Customer.new("mary") ])
  end

  def test_render_partial_collection_with_partial_name_containing_dot
    assert_equal "Hello: davidHello: mary",
      @view.render(:partial => "test/customer.mobile", :collection => [ Customer.new("david"), Customer.new("mary") ])
  end

  def test_render_partial_collection_as_by_string
    assert_equal "david david davidmary mary mary",
      @view.render(:partial => "test/customer_with_var", :collection => [ Customer.new("david"), Customer.new("mary") ], :as => "customer")
  end

  def test_render_partial_collection_as_by_symbol
    assert_equal "david david davidmary mary mary",
      @view.render(:partial => "test/customer_with_var", :collection => [ Customer.new("david"), Customer.new("mary") ], :as => :customer)
  end

  def test_render_partial_collection_without_as
    assert_equal "local_inspector,local_inspector_counter,local_inspector_iteration",
      @view.render(:partial => "test/local_inspector", :collection => [ Customer.new("mary") ])
  end

  def test_render_partial_with_empty_collection_should_return_nil
    assert_nil @view.render(:partial => "test/customer", :collection => [])
  end

  def test_render_partial_with_nil_collection_should_return_nil
    assert_nil @view.render(:partial => "test/customer", :collection => nil)
  end

  def test_render_partial_collection_for_non_array
    customers = Enumerator.new do |y|
      y.yield(Customer.new("david"))
      y.yield(Customer.new("mary"))
    end
    assert_equal "Hello: davidHello: mary", @view.render(partial: "test/customer", collection: customers)
  end

  def test_render_partial_without_object_does_not_put_partial_name_to_local_assigns
    assert_equal "false", @view.render(partial: "test/partial_name_in_local_assigns")
  end

  def test_render_partial_with_nil_object_puts_partial_name_to_local_assigns
    assert_equal "true", @view.render(partial: "test/partial_name_in_local_assigns", object: nil)
  end

  def test_render_partial_with_nil_values_in_collection
    assert_equal "Hello: davidHello: Anonymous", @view.render(:partial => "test/customer", :collection => [ Customer.new("david"), nil ])
  end

  def test_render_partial_with_layout_using_collection_and_template
    assert_equal "<b>Hello: Amazon</b><b>Hello: Yahoo</b>", @view.render(:partial => "test/customer", :layout => "test/b_layout_for_partial", :collection => [ Customer.new("Amazon"), Customer.new("Yahoo") ])
  end

  def test_render_partial_with_layout_using_collection_and_template_makes_current_item_available_in_layout
    assert_equal '<b class="amazon">Hello: Amazon</b><b class="yahoo">Hello: Yahoo</b>',
      @view.render(:partial => "test/customer", :layout => "test/b_layout_for_partial_with_object", :collection => [ Customer.new("Amazon"), Customer.new("Yahoo") ])
  end

  def test_render_partial_with_layout_using_collection_and_template_makes_current_item_counter_available_in_layout
    assert_equal '<b data-counter="0">Hello: Amazon</b><b data-counter="1">Hello: Yahoo</b>',
      @view.render(:partial => "test/customer", :layout => "test/b_layout_for_partial_with_object_counter", :collection => [ Customer.new("Amazon"), Customer.new("Yahoo") ])
  end

  def test_render_partial_with_layout_using_object_and_template_makes_object_available_in_layout
    assert_equal '<b class="amazon">Hello: Amazon</b>',
      @view.render(:partial => "test/customer", :layout => "test/b_layout_for_partial_with_object", :object => Customer.new("Amazon"))
  end

  def test_render_partial_with_empty_array_should_return_nil
    assert_nil @view.render(:partial => [])
  end

  def test_render_partial_using_string
    assert_equal "Hello: Anonymous", @controller_view.render("customer")
  end

  def test_render_partial_with_locals_using_string
    assert_equal "Hola: david", @controller_view.render("customer_greeting", :greeting => "Hola", :customer_greeting => Customer.new("david"))
  end

  def test_render_partial_with_object_uses_render_partial_path
    assert_equal "Hello: lifo",
      @controller_view.render(:partial => Customer.new("lifo"), :locals => {:greeting => "Hello"})
  end

  def test_render_partial_with_object_and_format_uses_render_partial_path
    assert_equal "<greeting>Hello</greeting><name>lifo</name>",
      @controller_view.render(:partial => Customer.new("lifo"), :formats => :xml, :locals => {:greeting => "Hello"})
  end

  def test_render_partial_using_object
    assert_equal "Hello: lifo",
      @controller_view.render(Customer.new("lifo"), :greeting => "Hello")
  end

  def test_render_partial_using_collection
    customers = [ Customer.new("Amazon"), Customer.new("Yahoo") ]
    assert_equal "Hello: AmazonHello: Yahoo",
      @controller_view.render(customers, :greeting => "Hello")
  end

  def test_render_partial_using_collection_without_path
    assert_equal "hi good customer: david0", @controller_view.render([ GoodCustomer.new("david") ], greeting: "hi")
  end

  def test_render_partial_without_object_or_collection_does_not_generate_partial_name_local_variable
    exception = assert_raises ActionView::Template::Error do
      @controller_view.render("partial_name_local_variable")
    end
    assert_instance_of NameError, exception.cause
    assert_equal :partial_name_local_variable, exception.cause.name
  end

  # TODO: The reason for this test is unclear, improve documentation
  def test_render_partial_and_fallback_to_layout
    assert_equal "Before (Josh)\n\nAfter", @view.render(:partial => "test/layout_for_partial", :locals => { :name => "Josh" })
  end

  # TODO: The reason for this test is unclear, improve documentation
  def test_render_missing_xml_partial_and_raise_missing_template
    @view.formats = [:xml]
    assert_raises(ActionView::MissingTemplate) { @view.render(:partial => "test/layout_for_partial") }
  ensure
    @view.formats = nil
  end

  def test_render_layout_with_block_and_other_partial_inside
    render = @view.render(:layout => "test/layout_with_partial_and_yield") { "Yield!" }
    assert_equal "Before\npartial html\nYield!\nAfter\n", render
  end

  def test_render_inline
    assert_equal "Hello, World!", @view.render(:inline => "Hello, World!")
  end

  def test_render_inline_with_locals
    assert_equal "Hello, Josh!", @view.render(:inline => "Hello, <%= name %>!", :locals => { :name => "Josh" })
  end

  def test_render_fallbacks_to_erb_for_unknown_types
    assert_equal "Hello, World!", @view.render(:inline => "Hello, World!", :type => :bar)
  end

  CustomHandler = lambda do |template|
    "@output_buffer = ''\n" +
      "@output_buffer << 'source: #{template.source.inspect}'\n"
  end

  def test_render_inline_with_render_from_to_proc
    ActionView::Template.register_template_handler :ruby_handler, :source.to_proc
    assert_equal "3", @view.render(inline: "(1 + 2).to_s", type: :ruby_handler)
  ensure
    ActionView::Template.unregister_template_handler :ruby_handler
  end

  def test_render_inline_with_compilable_custom_type
    ActionView::Template.register_template_handler :foo, CustomHandler
    assert_equal 'source: "Hello, World!"', @view.render(inline: "Hello, World!", type: :foo)
  ensure
    ActionView::Template.unregister_template_handler :foo
  end

  def test_render_inline_with_locals_and_compilable_custom_type
    ActionView::Template.register_template_handler :foo, CustomHandler
    assert_equal 'source: "Hello, <%= name %>!"', @view.render(inline: "Hello, <%= name %>!", locals: { name: "Josh" }, type: :foo)
  ensure
    ActionView::Template.unregister_template_handler :foo
  end

  def test_render_body
    assert_equal "some body", @view.render(body: "some body")
  end

  def test_render_plain
    assert_equal "some plaintext", @view.render(plain: "some plaintext")
  end

  def test_render_knows_about_types_registered_when_extensions_are_checked_earlier_in_initialization
    ActionView::Template::Handlers.extensions
    ActionView::Template.register_template_handler :foo, CustomHandler
    assert ActionView::Template::Handlers.extensions.include?(:foo)
  ensure
    ActionView::Template.unregister_template_handler :foo
  end

  def test_render_does_not_use_unregistered_extension_and_template_handler
    ActionView::Template.register_template_handler :foo, CustomHandler
    ActionView::Template.unregister_template_handler :foo
    assert_not ActionView::Template::Handlers.extensions.include?(:foo)
    assert_equal "Hello, World!", @view.render(inline: "Hello, World!", type: :foo)
  ensure
    ActionView::Template::Handlers.class_variable_get(:@@template_handlers).delete(:foo)
  end

  def test_render_ignores_templates_with_malformed_template_handlers
    ActiveSupport::Deprecation.silence do
      %w(malformed malformed.erb malformed.html.erb malformed.en.html.erb).each do |name|
        assert File.exist?(File.expand_path("#{FIXTURE_LOAD_PATH}/test/malformed/#{name}~")), "Malformed file (#{name}~) which should be ignored does not exists"
        assert_raises(ActionView::MissingTemplate) { @view.render(:file => "test/malformed/#{name}") }
      end
    end
  end

  def test_render_with_layout
    assert_equal %(<title></title>\nHello world!\n),
      @view.render(:file => "test/hello_world", :layout => "layouts/yield")
  end

  def test_render_with_layout_which_has_render_inline
    assert_equal %(welcome\nHello world!\n),
      @view.render(:file => "test/hello_world", :layout => "layouts/yield_with_render_inline_inside")
  end

  def test_render_with_layout_which_renders_another_partial
    assert_equal %(partial html\nHello world!\n),
      @view.render(:file => "test/hello_world", :layout => "layouts/yield_with_render_partial_inside")
  end

  def test_render_partial_with_html_only_extension
    assert_equal %(<h1>partial html</h1>\nHello world!\n),
      @view.render(:file => "test/hello_world", :layout => "layouts/render_partial_html")
  end

  def test_render_layout_with_block_and_yield
    assert_equal %(Content from block!\n),
      @view.render(:layout => "layouts/yield_only") { "Content from block!" }
  end

  def test_render_layout_with_block_and_yield_with_params
    assert_equal %(Yield! Content from block!\n),
      @view.render(:layout => "layouts/yield_with_params") { |param| "#{param} Content from block!" }
  end

  def test_render_layout_with_block_which_renders_another_partial_and_yields
    assert_equal %(partial html\nContent from block!\n),
      @view.render(:layout => "layouts/partial_and_yield") { "Content from block!" }
  end

  def test_render_partial_and_layout_without_block_with_locals
    assert_equal %(Before (Foo!)\npartial html\nAfter),
      @view.render(:partial => "test/partial", :layout => "test/layout_for_partial", :locals => { :name => "Foo!"})
  end

  def test_render_partial_and_layout_without_block_with_locals_and_rendering_another_partial
    assert_equal %(Before (Foo!)\npartial html\npartial with partial\n\nAfter),
      @view.render(:partial => "test/partial_with_partial", :layout => "test/layout_for_partial", :locals => { :name => "Foo!"})
  end

  def test_render_partial_shortcut_with_block_content
    assert_equal %(Before (shortcut test)\nBefore\n\n  Yielded: arg1/arg2\n\nAfter\nAfter),
      @view.render(partial: "test/partial_shortcut_with_block_content", layout: "test/layout_for_partial", locals: { name: "shortcut test" })
  end

  def test_render_layout_with_a_nested_render_layout_call
    assert_equal %(Before (Foo!)\nBefore (Bar!)\npartial html\nAfter\npartial with layout\n\nAfter),
      @view.render(:partial => "test/partial_with_layout", :layout => "test/layout_for_partial", :locals => { :name => "Foo!"})
  end

  def test_render_layout_with_a_nested_render_layout_call_using_block_with_render_partial
    assert_equal %(Before (Foo!)\nBefore (Bar!)\n\n  partial html\n\nAfterpartial with layout\n\nAfter),
      @view.render(:partial => "test/partial_with_layout_block_partial", :layout => "test/layout_for_partial", :locals => { :name => "Foo!"})
  end

  def test_render_layout_with_a_nested_render_layout_call_using_block_with_render_content
    assert_equal %(Before (Foo!)\nBefore (Bar!)\n\n  Content from inside layout!\n\nAfterpartial with layout\n\nAfter),
      @view.render(:partial => "test/partial_with_layout_block_content", :layout => "test/layout_for_partial", :locals => { :name => "Foo!"})
  end

  def test_render_partial_with_layout_raises_descriptive_error
    e = assert_raises(ActionView::MissingTemplate) { @view.render(partial: "test/partial", layout: true) }
    assert_match "Missing partial /_true with", e.message
  end

  def test_render_with_nested_layout
    assert_equal %(<title>title</title>\n\n<div id="column">column</div>\n<div id="content">content</div>\n),
      @view.render(:file => "test/nested_layout", :layout => "layouts/yield")
  end

  def test_render_with_file_in_layout
    assert_equal %(\n<title>title</title>\n\n),
      @view.render(:file => "test/layout_render_file")
  end

  def test_render_layout_with_object
    assert_equal %(<title>David</title>),
      @view.render(:file => "test/layout_render_object")
  end

  def test_render_with_passing_couple_extensions_to_one_register_template_handler_function_call
    ActionView::Template.register_template_handler :foo1, :foo2, CustomHandler
    assert_equal @view.render(inline: "Hello, World!", type: :foo1), @view.render(inline: "Hello, World!", type: :foo2)
  ensure
    ActionView::Template.unregister_template_handler :foo1, :foo2
  end

  def test_render_throws_exception_when_no_extensions_passed_to_register_template_handler_function_call
    assert_raises(ArgumentError) { ActionView::Template.register_template_handler CustomHandler }
  end
end

class CachedViewRenderTest < ActiveSupport::TestCase
  include RenderTestCases

  # Ensure view path cache is primed
  def setup
    view_paths = ActionController::Base.view_paths
    assert_equal ActionView::OptimizedFileSystemResolver, view_paths.first.class
    setup_view(view_paths)
  end

  def teardown
    GC.start
    I18n.reload!
  end
end

class LazyViewRenderTest < ActiveSupport::TestCase
  include RenderTestCases

  # Test the same thing as above, but make sure the view path
  # is not eager loaded
  def setup
    path = ActionView::FileSystemResolver.new(FIXTURE_LOAD_PATH)
    view_paths = ActionView::PathSet.new([path])
    assert_equal ActionView::FileSystemResolver.new(FIXTURE_LOAD_PATH), view_paths.first
    setup_view(view_paths)
  end

  def teardown
    GC.start
    I18n.reload!
  end

  def test_render_utf8_template_with_magic_comment
    with_external_encoding Encoding::ASCII_8BIT do
      result = @view.render(:file => "test/utf8_magic", :formats => [:html], :layouts => "layouts/yield")
      assert_equal Encoding::UTF_8, result.encoding
      assert_equal "\nРусский \nтекст\n\nUTF-8\nUTF-8\nUTF-8\n", result
    end
  end

  def test_render_utf8_template_with_default_external_encoding
    with_external_encoding Encoding::UTF_8 do
      result = @view.render(:file => "test/utf8", :formats => [:html], :layouts => "layouts/yield")
      assert_equal Encoding::UTF_8, result.encoding
      assert_equal "Русский текст\n\nUTF-8\nUTF-8\nUTF-8\n", result
    end
  end

  def test_render_utf8_template_with_incompatible_external_encoding
    with_external_encoding Encoding::SHIFT_JIS do
      e = assert_raises(ActionView::Template::Error) { @view.render(:file => "test/utf8", :formats => [:html], :layouts => "layouts/yield") }
      assert_match "Your template was not saved as valid Shift_JIS", e.cause.message
    end
  end

  def test_render_utf8_template_with_partial_with_incompatible_encoding
    with_external_encoding Encoding::SHIFT_JIS do
      e = assert_raises(ActionView::Template::Error) { @view.render(:file => "test/utf8_magic_with_bare_partial", :formats => [:html], :layouts => "layouts/yield") }
      assert_match "Your template was not saved as valid Shift_JIS", e.cause.message
    end
  end

  def with_external_encoding(encoding)
    old = Encoding.default_external
    silence_warnings { Encoding.default_external = encoding }
    yield
  ensure
    silence_warnings { Encoding.default_external = old }
  end
end

class CachedCollectionViewRenderTest < ActiveSupport::TestCase
  class CachedCustomer < Customer; end

  include RenderTestCases

  # Ensure view path cache is primed
  setup do
    view_paths = ActionController::Base.view_paths
    assert_equal ActionView::OptimizedFileSystemResolver, view_paths.first.class

    ActionView::PartialRenderer.collection_cache = ActiveSupport::Cache::MemoryStore.new

    setup_view(view_paths)
  end

  teardown do
    GC.start
    I18n.reload!
  end

  test "collection caching does not cache by default" do
    customer = Customer.new("david", 1)
    key = cache_key(customer, "test/_customer")

    ActionView::PartialRenderer.collection_cache.write(key, "Cached")

    assert_not_equal "Cached",
      @view.render(partial: "test/customer", collection: [customer])
  end

  test "collection caching with partial that doesn't use fragment caching" do
    customer = Customer.new("david", 1)
    key = cache_key(customer, "test/_customer")

    ActionView::PartialRenderer.collection_cache.write(key, "Cached")

    assert_equal "Cached",
      @view.render(partial: "test/customer", collection: [customer], cached: true)
  end

  test "collection caching with cached true" do
    customer = CachedCustomer.new("david", 1)
    key = cache_key(customer, "test/_cached_customer")

    ActionView::PartialRenderer.collection_cache.write(key, "Cached")

    assert_equal "Cached",
      @view.render(partial: "test/cached_customer", collection: [customer], cached: true)
  end

  private
    def cache_key(*names, virtual_path)
      digest = ActionView::Digestor.digest name: virtual_path, finder: @view.lookup_context, dependencies: []
      @view.fragment_cache_key([ *names, digest ])
    end
end
