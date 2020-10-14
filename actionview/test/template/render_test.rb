# frozen_string_literal: true

require "abstract_unit"
require "controller/fake_models"
require "test_renderable"
require "active_model/validations"

class TestController < ActionController::Base
end

module RenderTestCases
  def setup_view(paths)
    @assigns = { secret: "in the sauce" }

    @view = Class.new(ActionView::Base.with_empty_template_cache) do
      def view_cache_dependencies; []; end

      def combined_fragment_cache_key(key)
        [ :views, key ]
      end
    end.with_view_paths(paths, @assigns)

    controller = TestController.new
    controller.perform_caching = true
    controller.cache_store = :memory_store
    @view.controller = controller

    @controller_view = controller.view_context_class.with_empty_template_cache.new(
      controller.lookup_context,
      controller.view_assigns,
      controller)

    # Reload and register danish language for testing
    I18n.backend.store_translations "da", {}
    I18n.backend.store_translations "pt-BR", {}

    # Ensure original are still the same since we are reindexing view paths
    assert_equal ORIGINAL_LOCALES, I18n.available_locales.map(&:to_s).sort
  end

  def teardown
    I18n.reload!
    ActionController::Base.view_paths.map(&:clear_cache)
  end

  def test_implicit_format_comes_from_parent_template
    rendered_templates = JSON.parse(@controller_view.render(template: "test/mixing_formats"))
    assert_equal({ "format" => "HTML",
                   "children" => ["XML", "HTML"] }, rendered_templates)
  end

  def test_implicit_format_comes_from_parent_template_cascading
    rendered_templates = JSON.parse(@controller_view.render(template: "test/mixing_formats_deep"))
    assert_equal({ "format" => "HTML",
                   "children" => [
                     { "format" => "XML", "children" => ["XML"] },
                     { "format" => "HTML", "children" => ["HTML"] },
    ] }, rendered_templates)
  end

  def test_explicit_js_format_adds_html_fallback
    rendered_templates = @controller_view.render(template: "test/js_html_fallback", formats: :js)
    assert_equal(%Q(document.write("<b>Hello from a HTML partial!<\\/b>")\n), rendered_templates)
  end

  def test_render_without_options
    e = assert_raises(ArgumentError) { @view.render() }
    assert_match(/You invoked render but did not give any of (.+) option\./, e.message)
  end

  def test_render_template
    assert_equal "Hello world!", @view.render(template: "test/hello_world")
  end

  def test_render_file
    assert_equal "Hello world!", assert_deprecated { @view.render(file: "test/hello_world") }
  end

  # Test if :formats, :locale etc. options are passed correctly to the resolvers.
  def test_render_file_with_format
    assert_match "<h1>No Comment</h1>", assert_deprecated { @view.render(file: "comments/empty", formats: [:html]) }
    assert_match "<error>No Comment</error>", assert_deprecated { @view.render(file: "comments/empty", formats: [:xml]) }
    assert_match "<error>No Comment</error>", assert_deprecated { @view.render(file: "comments/empty", formats: :xml) }
  end

  def test_render_template_with_format
    assert_match "<h1>No Comment</h1>", @view.render(template: "comments/empty", formats: [:html])
    assert_match "<error>No Comment</error>", @view.render(template: "comments/empty", formats: [:xml])
    assert_match "<error>No Comment</error>", @view.render(template: "comments/empty", formats: :xml)
  end

  def test_render_partial_implicitly_use_format_of_the_rendered_template
    @view.lookup_context.formats = [:json]
    assert_equal "Hello world", @view.render(template: "test/one", formats: [:html])
  end

  def test_render_partial_implicitly_use_format_of_the_rendered_partial
    @view.lookup_context.formats = [:html]
    assert_equal "Third level", @view.render(template: "test/html_template")
  end

  def test_render_partial_use_last_prepended_format_for_partials_with_the_same_names
    @view.lookup_context.formats = [:html]
    assert_equal "\nHTML Template, but HTML partial", @view.render(template: "test/change_priority")
  end

  def test_render_template_with_a_missing_partial_of_another_format
    @view.lookup_context.formats = [:html]
    e = assert_raise ActionView::Template::Error do
      @view.render(template: "with_format", formats: [:json])
    end
    assert_includes(e.message, "Missing partial /_missing with {:locale=>[:en], :formats=>[:json], :variants=>[], :handlers=>[:raw, :erb, :html, :builder, :ruby]}.")
  end

  def test_render_file_with_locale
    assert_equal "<h1>Kein Kommentar</h1>", assert_deprecated { @view.render(file: "comments/empty", locale: [:de]) }
    assert_equal "<h1>Kein Kommentar</h1>", assert_deprecated { @view.render(file: "comments/empty", locale: :de) }
  end

  def test_render_template_with_locale
    assert_equal "<h1>Kein Kommentar</h1>", @view.render(template: "comments/empty", locale: [:de])
  end

  def test_render_template_with_variants
    assert_equal "<h1>No Comment</h1>\n", @view.render(template: "comments/empty", variants: :grid)
  end

  def test_render_file_with_handlers
    assert_equal "<h1>No Comment</h1>\n", assert_deprecated { @view.render(file: "comments/empty", handlers: [:builder]) }
    assert_equal "<h1>No Comment</h1>\n", assert_deprecated { @view.render(file: "comments/empty", handlers: :builder) }
  end

  def test_render_template_with_handlers
    assert_equal "<h1>No Comment</h1>\n", @view.render(template: "comments/empty", handlers: [:builder])
  end

  def test_render_raw_template_with_handlers
    assert_equal "<%= hello_world %>\n", @view.render(template: "plain_text")
  end

  def test_render_raw_template_with_quotes
    assert_equal %q;Here are some characters: !@#$%^&*()-="'}{`; + "\n", @view.render(template: "plain_text_with_characters")
  end

  def test_render_raw_is_html_safe_and_does_not_escape_output
    buffer = ActiveSupport::SafeBuffer.new
    buffer << @view.render(template: "plain_text")
    assert_equal true, buffer.html_safe?
    assert_equal buffer, "<%= hello_world %>\n"
  end

  def test_render_ruby_template_with_handlers
    assert_equal "Hello from Ruby code", @view.render(template: "ruby_template")
  end

  def test_render_ruby_template_inline
    assert_equal "4", @view.render(inline: "(2**2).to_s", type: :ruby)
  end

  def test_render_template_with_localization_on_context_level
    old_locale, @view.locale = @view.locale, :da
    assert_equal "Hey verden", @view.render(template: "test/hello_world")
  ensure
    @view.locale = old_locale
  end

  def test_render_template_with_dashed_locale
    old_locale, @view.locale = @view.locale, :"pt-BR"
    assert_equal "Ola mundo", @view.render(template: "test/hello_world")
  ensure
    @view.locale = old_locale
  end

  def test_render_template_at_top_level
    assert_equal "Elastica", @view.render(template: "/shared")
  end

  def test_render_file_with_full_path_no_extension
    template_path = File.expand_path("../fixtures/test/hello_world", __dir__)
    assert_equal "Hello world!", assert_deprecated { @view.render(file: template_path) }
  end

  def test_render_file_with_full_path
    template_path = File.expand_path("../fixtures/test/hello_world.erb", __dir__)
    assert_equal "Hello world!", @view.render(file: template_path)
  end

  def test_render_file_with_instance_variables
    assert_equal "The secret is in the sauce\n", assert_deprecated { @view.render(file: "test/render_file_with_ivar") }
  end

  def test_render_file_with_locals
    locals = { secret: "in the sauce" }
    assert_equal "The secret is in the sauce\n", assert_deprecated { @view.render(file: "test/render_file_with_locals", locals: locals) }
  end

  def test_render_file_not_using_full_path_with_dot_in_path
    assert_equal "The secret is in the sauce\n", assert_deprecated { @view.render(file: "test/dot.directory/render_file_with_ivar") }
  end

  def test_render_partial_from_default
    assert_equal "only partial", @view.render("test/partial_only")
  end

  def test_render_outside_path
    assert File.exist?(File.expand_path("../../test/abstract_unit.rb", __dir__))
    assert_raises ActionView::MissingTemplate do
      assert_deprecated do
        @view.render(template: "../\\../test/abstract_unit.rb")
      end
    end
  end

  def test_render_partial
    assert_equal "only partial", @view.render(partial: "test/partial_only")
  end

  def test_render_partial_with_format
    assert_equal "partial html", @view.render(partial: "test/partial")
  end

  def test_render_partial_with_variants
    assert_equal "<h1>Partial with variants</h1>\n", @view.render(partial: "test/partial_with_variants", variants: :grid)
  end

  def test_render_partial_with_selected_format
    assert_equal "partial html", @view.render(partial: "test/partial", formats: :html)
    assert_equal "partial js", @view.render(partial: "test/partial", formats: [:js])
  end

  def test_render_partial_at_top_level
    # file fixtures/_top_level_partial_only (not fixtures/test)
    assert_equal "top level partial", @view.render(partial: "/top_level_partial_only")
  end

  def test_render_partial_with_format_at_top_level
    # file fixtures/_top_level_partial.html (not fixtures/test, with format extension)
    assert_equal "top level partial html", @view.render(partial: "/top_level_partial")
  end

  def test_render_partial_with_locals
    assert_equal "5", @view.render(partial: "test/counter", locals: { counter_counter: 5 })
  end

  def test_render_partial_with_locals_from_default
    assert_equal "only partial", @view.render("test/partial_only", counter_counter: 5)
  end

  def test_render_partial_with_number
    assert_nothing_raised { @view.render(partial: "test/200") }
  end

  def test_render_partial_with_missing_filename
    assert_raises(ActionView::MissingTemplate) { @view.render(partial: "test/") }
  end

  def test_render_partial_with_incompatible_object
    e = assert_raises(ArgumentError) { @view.render(partial: nil) }
    assert_equal "'#{nil.inspect}' is not an ActiveModel-compatible object. It must implement :to_partial_path.", e.message
  end

  def test_render_partial_starting_with_a_capital
    assert_nothing_raised { @view.render(partial: "test/FooBar") }
  end

  def test_render_partial_with_hyphen
    assert_nothing_raised { @view.render(partial: "test/a-in") }
  end

  def test_render_partial_with_unicode_text
    assert_nothing_raised { @view.render(partial: "test/🍣") }
  end

  def test_render_partial_with_invalid_option_as
    e = assert_raises(ArgumentError) { @view.render(partial: "test/partial_only", as: "a-in", object: nil) }
    assert_equal "The value (a-in) of the option `as` is not a valid Ruby identifier; " \
      "make sure it starts with lowercase letter, " \
      "and is followed by any combination of letters, numbers and underscores.", e.message
  end

  def test_render_partial_with_hyphen_and_invalid_option_as
    e = assert_raises(ArgumentError) { @view.render(partial: "test/a-in", as: "a-in", object: nil) }
    assert_equal "The value (a-in) of the option `as` is not a valid Ruby identifier; " \
      "make sure it starts with lowercase letter, " \
      "and is followed by any combination of letters, numbers and underscores.", e.message
  end

  def test_render_template_with_syntax_error
    e = assert_raises(ActionView::Template::Error) { @view.render(template: "test/syntax_error") }
    assert_match %r!syntax!, e.message
    assert_equal "1:    <%= foo(", e.annotated_source_code[0].strip
  end

  def test_render_partial_with_errors
    e = assert_raises(ActionView::Template::Error) { @view.render(partial: "test/raise") }
    assert_match %r!method.*doesnt_exist!, e.message
    assert_equal "", e.sub_template_message
    assert_equal "1", e.line_number
    assert_equal "1: <%= doesnt_exist %>", e.annotated_source_code[0].strip
    assert_equal File.expand_path("#{FIXTURE_LOAD_PATH}/test/_raise.html.erb"), e.file_name
  end

  def test_render_error_indentation
    e = assert_raises(ActionView::Template::Error) { @view.render(partial: "test/raise_indentation") }
    error_lines = e.annotated_source_code
    assert_match %r!error\shere!, e.message
    assert_equal "11", e.line_number
    assert_equal "     9: <p>Ninth paragraph</p>", error_lines.second
    assert_equal "    10: <p>Tenth paragraph</p>", error_lines.third
  end

  def test_render_sub_template_with_errors
    e = assert_raises(ActionView::Template::Error) { @view.render(template: "test/sub_template_raise") }
    assert_match %r!method.*doesnt_exist!, e.message
    assert_match %r{Trace of template inclusion: .*test/sub_template_raise\.html\.erb}, e.sub_template_message
    assert_equal "1", e.line_number
    assert_equal File.expand_path("#{FIXTURE_LOAD_PATH}/test/_raise.html.erb"), e.file_name
  end

  def test_render_file_with_errors
    e = assert_raises(ActionView::Template::Error) { assert_deprecated { @view.render(file: File.expand_path("test/_raise", FIXTURE_LOAD_PATH)) } }
    assert_match %r!method.*doesnt_exist!, e.message
    assert_equal "", e.sub_template_message
    assert_equal "1", e.line_number
    assert_equal "1: <%= doesnt_exist %>", e.annotated_source_code[0].strip
    assert_equal File.expand_path("#{FIXTURE_LOAD_PATH}/test/_raise.html.erb"), e.file_name
  end

  def test_undefined_method_error_references_named_class
    e = assert_raises(ActionView::Template::Error) { @view.render(inline: "<%= undefined %>") }
    assert_match(/`undefined' for #<ActionView::Base:0x[0-9a-f]+>/, e.message)
  end

  def test_render_renderable_object
    assert_equal "Hello: david", @view.render(partial: "test/customer", object: Customer.new("david"))
    assert_equal "FalseClass", @view.render(partial: "test/klass", object: false)
    assert_equal "NilClass", @view.render(partial: "test/klass", object: nil)
  end

  def test_render_object_different_name
    assert_equal "Hello: t.lo", @view.render(partial: "test/template_not_named_customer", object: Customer.new("t.lo"), as: "customer").chomp
  end

  def test_render_object_with_array
    assert_equal "[1, 2, 3]", @view.render(partial: "test/object_inspector", object: [1, 2, 3])
  end

  def test_render_partial_collection
    assert_equal "Hello: davidHello: mary", @view.render(partial: "test/customer", collection: [ Customer.new("david"), Customer.new("mary") ])
  end

  def test_render_partial_collection_with_partial_name_containing_dot
    assert_deprecated do
      assert_equal "Hello: davidHello: mary",
        @view.render(partial: "test/customer.mobile", collection: [ Customer.new("david"), Customer.new("mary") ])
    end
  end

  def test_render_partial_collection_as_by_string
    assert_equal "david david davidmary mary mary",
      @view.render(partial: "test/customer_with_var", collection: [ Customer.new("david"), Customer.new("mary") ], as: "customer")
  end

  def test_render_partial_collection_as_by_symbol
    assert_equal "david david davidmary mary mary",
      @view.render(partial: "test/customer_with_var", collection: [ Customer.new("david"), Customer.new("mary") ], as: :customer)
  end

  def test_render_partial_collection_without_as
    assert_equal "local_inspector,local_inspector_counter,local_inspector_iteration",
      @view.render(partial: "test/local_inspector", collection: [ Customer.new("mary") ])
  end

  def test_render_partial_collection_with_different_partials_still_provides_partial_iteration
    a = {}
    b = {}
    def a.to_partial_path; "test/partial_iteration_1"; end
    def b.to_partial_path; "test/partial_iteration_2"; end

    assert_equal "local-variable\nlocal-variable", @controller_view.render([a, b])
  end

  def test_render_partial_with_empty_collection_should_return_nil
    assert_nil @view.render(partial: "test/customer", collection: [])
  end

  def test_render_partial_with_nil_collection_should_return_nil
    assert_nil @view.render(partial: "test/customer", collection: nil)
  end

  def test_render_partial_collection_for_non_array
    customers = Enumerator.new do |y|
      y.yield(Customer.new("david"))
      y.yield(Customer.new("mary"))
    end
    assert_equal "Hello: davidHello: mary", @view.render(partial: "test/customer", collection: customers)
  end

  def test_deprecated_constructor
    assert_deprecated do
      ActionView::Base.new
    end

    assert_deprecated do
      ActionView::Base.new ["/a"]
    end

    assert_deprecated do
      ActionView::Base.new ActionView::PathSet.new ["/a"]
    end
  end

  def test_without_compiled_method_container_is_deprecated
    view = ActionView::Base.with_view_paths(ActionController::Base.view_paths)
    assert_deprecated("ActionView::Base instances must implement `compiled_method_container`") do
      assert_equal "Hello world!", view.render(template: "test/hello_world")
    end
  end

  def test_render_partial_without_object_does_not_put_partial_name_to_local_assigns
    assert_equal "false", @view.render(partial: "test/partial_name_in_local_assigns")
  end

  def test_render_partial_with_nil_object_puts_partial_name_to_local_assigns
    assert_equal "true", @view.render(partial: "test/partial_name_in_local_assigns", object: nil)
  end

  def test_render_partial_with_nil_values_in_collection
    assert_equal "Hello: davidHello: Anonymous", @view.render(partial: "test/customer", collection: [ Customer.new("david"), nil ])
  end

  def test_render_partial_with_layout_using_collection_and_template
    assert_equal "<b>Hello: Amazon</b><b>Hello: Yahoo</b>", @view.render(partial: "test/customer", layout: "test/b_layout_for_partial", collection: [ Customer.new("Amazon"), Customer.new("Yahoo") ])
  end

  def test_render_partial_with_layout_using_collection_and_template_makes_current_item_available_in_layout
    assert_equal '<b class="amazon">Hello: Amazon</b><b class="yahoo">Hello: Yahoo</b>',
      @view.render(partial: "test/customer", layout: "test/b_layout_for_partial_with_object", collection: [ Customer.new("Amazon"), Customer.new("Yahoo") ])
  end

  def test_render_partial_with_layout_using_collection_and_template_makes_current_item_counter_available_in_layout
    assert_equal '<b data-counter="0">Hello: Amazon</b><b data-counter="1">Hello: Yahoo</b>',
      @view.render(partial: "test/customer", layout: "test/b_layout_for_partial_with_object_counter", collection: [ Customer.new("Amazon"), Customer.new("Yahoo") ])
  end

  def test_render_partial_with_layout_using_object_and_template_makes_object_available_in_layout
    assert_equal '<b class="amazon">Hello: Amazon</b>',
      @view.render(partial: "test/customer", layout: "test/b_layout_for_partial_with_object", object: Customer.new("Amazon"))
  end

  def test_render_partial_with_empty_array_should_return_nil
    assert_nil @view.render(partial: [])
  end

  def test_render_partial_using_string
    assert_equal "Hello: Anonymous", @controller_view.render("customer")
  end

  def test_render_partial_with_locals_using_string
    assert_equal "Hola: david", @controller_view.render("customer_greeting", greeting: "Hola", customer_greeting: Customer.new("david"))
  end

  def test_render_partial_with_object_uses_render_partial_path
    assert_equal "Hello: lifo",
      @controller_view.render(partial: Customer.new("lifo"), locals: { greeting: "Hello" })
  end

  def test_render_partial_with_object_and_format_uses_render_partial_path
    assert_equal "<greeting>Hello</greeting><name>lifo</name>",
      @controller_view.render(partial: Customer.new("lifo"), formats: :xml, locals: { greeting: "Hello" })
  end

  def test_render_partial_using_object
    assert_equal "Hello: lifo",
      @controller_view.render(Customer.new("lifo"), greeting: "Hello")
  end

  def test_render_partial_using_collection
    customers = [ Customer.new("Amazon"), Customer.new("Yahoo") ]
    assert_equal "Hello: AmazonHello: Yahoo",
      @controller_view.render(customers, greeting: "Hello")
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

  def test_render_partial_with_no_block_given_to_yield
    assert_equal "Before (Josh)\n\nAfter", @view.render(partial: "test/layout_for_partial", locals: { name: "Josh" })
  end

  def test_render_partial_with_non_existent_format_and_raise_missing_template
    @view.formats = [:xml]
    assert_raises(ActionView::MissingTemplate) { @view.render(partial: "test/layout_for_partial") }
  ensure
    @view.formats = nil
  end

  def test_render_layout_with_block_and_other_partial_inside
    render = @view.render(layout: "test/layout_with_partial_and_yield") { "Yield!" }
    assert_equal "Before\npartial html\nYield!\nAfter\n", render
  end

  def test_render_inline
    assert_equal "Hello, World!", @view.render(inline: "Hello, World!")
  end

  def test_render_inline_with_locals
    assert_equal "Hello, Josh!", @view.render(inline: "Hello, <%= name %>!", locals: { name: "Josh" })
  end

  def test_render_fallbacks_to_erb_for_unknown_types
    assert_equal "Hello, World!", @view.render(inline: "Hello, World!", type: :bar)
  end

  CustomHandler = lambda do |template, source|
    "@output_buffer = ''.dup\n" \
      "@output_buffer << 'source: #{source.inspect}'\n"
  end

  def test_render_inline_with_render_from_to_proc
    ActionView::Template.register_template_handler :ruby_handler, lambda { |_, source| source }
    assert_equal "3", @view.render(inline: "(1 + 2).to_s", type: :ruby_handler)
  ensure
    ActionView::Template.unregister_template_handler :ruby_handler
  end

  def test_render_inline_with_render_from_to_proc_deprecated
    assert_deprecated do
      ActionView::Template.register_template_handler :ruby_handler, :source.to_proc
    end
    assert_equal "3", @view.render(inline: "(1 + 2).to_s", type: :ruby_handler)
  ensure
    ActionView::Template.unregister_template_handler :ruby_handler
  end

  def test_optional_second_arg_works_without_deprecation
    assert_not_deprecated do
      ActionView::Template.register_template_handler :ruby_handler, ->(view, source = nil) { source }
    end
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
    assert_includes ActionView::Template::Handlers.extensions, :foo
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
    %w(malformed malformed.erb malformed.html.erb malformed.en.html.erb).each do |name|
      assert File.exist?(File.expand_path("#{FIXTURE_LOAD_PATH}/test/malformed/#{name}~")), "Malformed file (#{name}~) which should be ignored does not exists"
      assert_raises(ActionView::MissingTemplate) do
        ActiveSupport::Deprecation.silence do
          @view.render(template: "test/malformed/#{name}")
        end
      end
    end
  end

  def test_render_with_layout
    assert_equal %(<title></title>\nHello world!\n),
      @view.render(template: "test/hello_world", layout: "layouts/yield")
  end

  def test_render_with_layout_which_has_render_inline
    assert_equal %(welcome\nHello world!\n),
      @view.render(template: "test/hello_world", layout: "layouts/yield_with_render_inline_inside")
  end

  def test_render_with_layout_which_renders_another_partial
    assert_equal %(partial html\nHello world!\n),
      @view.render(template: "test/hello_world", layout: "layouts/yield_with_render_partial_inside")
  end

  def test_render_partial_with_html_only_extension
    assert_equal %(<h1>partial html</h1>\nHello world!\n),
      @view.render(template: "test/hello_world", layout: "layouts/render_partial_html")
  end

  def test_render_layout_with_block_and_yield
    assert_equal %(Content from block!\n),
      @view.render(layout: "layouts/yield_only") { "Content from block!" }
  end

  def test_render_layout_with_block_and_yield_with_params
    assert_equal %(Yield! Content from block!\n),
      @view.render(layout: "layouts/yield_with_params") { |param| "#{param} Content from block!" }
  end

  def test_render_layout_with_block_which_renders_another_partial_and_yields
    assert_equal %(partial html\nContent from block!\n),
      @view.render(layout: "layouts/partial_and_yield") { "Content from block!" }
  end

  def test_render_partial_and_layout_without_block_with_locals
    assert_equal %(Before (Foo!)\npartial html\nAfter),
      @view.render(partial: "test/partial", layout: "test/layout_for_partial", locals: { name: "Foo!" })
  end

  def test_render_partial_and_layout_without_block_with_locals_and_rendering_another_partial
    assert_equal %(Before (Foo!)\npartial html\npartial with partial\n\nAfter),
      @view.render(partial: "test/partial_with_partial", layout: "test/layout_for_partial", locals: { name: "Foo!" })
  end

  def test_render_partial_shortcut_with_block_content
    assert_equal %(Before (shortcut test)\nBefore\n\n  Yielded: arg1/arg2\n\nAfter\nAfter),
      @view.render(partial: "test/partial_shortcut_with_block_content", layout: "test/layout_for_partial", locals: { name: "shortcut test" })
  end

  def test_render_layout_with_a_nested_render_layout_call
    assert_equal %(Before (Foo!)\nBefore (Bar!)\npartial html\nAfter\npartial with layout\n\nAfter),
      @view.render(partial: "test/partial_with_layout", layout: "test/layout_for_partial", locals: { name: "Foo!" })
  end

  def test_render_layout_with_a_nested_render_layout_call_using_block_with_render_partial
    assert_equal %(Before (Foo!)\nBefore (Bar!)\n\n  partial html\n\nAfterpartial with layout\n\nAfter),
      @view.render(partial: "test/partial_with_layout_block_partial", layout: "test/layout_for_partial", locals: { name: "Foo!" })
  end

  def test_render_layout_with_a_nested_render_layout_call_using_block_with_render_content
    assert_equal %(Before (Foo!)\nBefore (Bar!)\n\n  Content from inside layout!\n\nAfterpartial with layout\n\nAfter),
      @view.render(partial: "test/partial_with_layout_block_content", layout: "test/layout_for_partial", locals: { name: "Foo!" })
  end

  def test_render_partial_with_layout_raises_descriptive_error
    e = assert_raises(ActionView::MissingTemplate) { @view.render(partial: "test/partial", layout: true) }
    assert_match "Missing partial /_true with", e.message
  end

  def test_render_with_nested_layout
    assert_equal %(<title>title</title>\n\n<div id="column">column</div>\n<div id="content">content</div>\n),
      @view.render(template: "test/nested_layout", layout: "layouts/yield")
  end

  def test_render_with_file_in_layout
    assert_equal %(\n<title>title</title>\n\n),
      @view.render(template: "test/layout_render_file")
  end

  def test_render_layout_with_object
    assert_equal %(<title>David</title>),
      @view.render(template: "test/layout_render_object")
  end

  def test_render_with_passing_couple_extensions_to_one_register_template_handler_function_call
    ActionView::Template.register_template_handler :foo1, :foo2, CustomHandler
    assert_equal @view.render(inline: +"Hello, World!", type: :foo1), @view.render(inline: +"Hello, World!", type: :foo2)
  ensure
    ActionView::Template.unregister_template_handler :foo1, :foo2
  end

  def test_render_throws_exception_when_no_extensions_passed_to_register_template_handler_function_call
    assert_raises(ArgumentError) { ActionView::Template.register_template_handler CustomHandler }
  end

  def test_render_object
    assert_equal(
      %(Hello, World!),
      @view.render(TestRenderable.new)
    )
  end
end

class CachedViewRenderTest < ActiveSupport::TestCase
  include RenderTestCases

  # Ensure view path cache is primed
  def setup
    ActionView::LookupContext::DetailsKey.clear
    view_paths = ActionController::Base.view_paths
    assert_equal ActionView::OptimizedFileSystemResolver, view_paths.first.class
    setup_view(view_paths)
  end

  def test_cache_fragments_inside_render_layout_call_with_block
    cat = @view.render(template: "test/cache_fragment_inside_render_layout_block_1")
    dog = @view.render(template: "test/cache_fragment_inside_render_layout_block_2")

    assert_not_equal cat, dog
  end
end

class LazyViewRenderTest < ActiveSupport::TestCase
  include RenderTestCases

  # Test the same thing as above, but make sure the view path
  # is not eager loaded
  def setup
    ActionView::LookupContext::DetailsKey.clear
    path = ActionView::FileSystemResolver.new(FIXTURE_LOAD_PATH)
    view_paths = ActionView::PathSet.new([path])
    assert_equal ActionView::FileSystemResolver.new(FIXTURE_LOAD_PATH), view_paths.first
    setup_view(view_paths)
  end

  def test_render_utf8_template_with_magic_comment
    with_external_encoding Encoding::ASCII_8BIT do
      result = @view.render(template: "test/utf8_magic", formats: [:html], layouts: "layouts/yield")
      assert_equal Encoding::UTF_8, result.encoding
      assert_equal "\nРусский \nтекст\n\nUTF-8\nUTF-8\nUTF-8\n", result
    end
  end

  def test_render_utf8_template_with_default_external_encoding
    with_external_encoding Encoding::UTF_8 do
      result = @view.render(template: "test/utf8", formats: [:html], layouts: "layouts/yield")
      assert_equal Encoding::UTF_8, result.encoding
      assert_equal "Русский текст\n\nUTF-8\nUTF-8\nUTF-8\n", result
    end
  end

  def test_render_utf8_template_with_incompatible_external_encoding
    with_external_encoding Encoding::SHIFT_JIS do
      e = assert_raises(ActionView::Template::Error) { @view.render(template: "test/utf8", formats: [:html], layouts: "layouts/yield") }
      assert_match "Your template was not saved as valid Shift_JIS", e.cause.message
    end
  end

  def test_render_utf8_template_with_partial_with_incompatible_encoding
    with_external_encoding Encoding::SHIFT_JIS do
      e = assert_raises(ActionView::Template::Error) { @view.render(template: "test/utf8_magic_with_bare_partial", formats: [:html], layouts: "layouts/yield") }
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
    ActionView::LookupContext::DetailsKey.clear

    view_paths = ActionController::Base.view_paths
    assert_equal ActionView::OptimizedFileSystemResolver, view_paths.first.class

    ActionView::PartialRenderer.collection_cache = ActiveSupport::Cache::MemoryStore.new

    setup_view(view_paths)
  end

  test "template body written to cache" do
    customer = Customer.new("david", 1)
    key = cache_key(customer, "test/_customer")
    assert_nil ActionView::PartialRenderer.collection_cache.read(key)
    @view.render(partial: "test/customer", collection: [customer], cached: true)
    assert_equal "Hello: david", ActionView::PartialRenderer.collection_cache.read(key)
  end

  test "collection caching does not cache by default" do
    customer = Customer.new("david", 1)
    key = cache_key(customer, "test/_customer")

    ActionView::PartialRenderer.collection_cache.write(key, "Cached")

    assert_not_equal "Cached",
      @view.render(partial: "test/customer", collection: [customer])
  end

  test "collection caching does not cache if controller doesn't respond to perform_caching" do
    @view.controller = nil

    customer = Customer.new("david", 1)
    key = cache_key(customer, "test/_customer")

    ActionView::PartialRenderer.collection_cache.write(key, "Cached")

    assert_not_equal "Cached",
      @view.render(partial: "test/customer", collection: [customer], cached: true)
  end

  test "collection caching does not cache if perform_caching is disabled" do
    @view.controller.perform_caching = false

    customer = Customer.new("david", 1)
    key = cache_key(customer, "test/_customer")

    ActionView::PartialRenderer.collection_cache.write(key, "Cached")

    assert_not_equal "Cached",
      @view.render(partial: "test/customer", collection: [customer], cached: true)
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

  test "collection caching does not work on multi-partials" do
    a = Object.new
    b = Object.new
    def a.to_partial_path; "test/partial_iteration_1"; end
    def b.to_partial_path; "test/partial_iteration_2"; end

    assert_raises(NotImplementedError) do
      @controller_view.render(partial: [a, b], cached: true)
    end
  end

  test "collection caching with repeated collection" do
    sets = [
        [1, 2, 3, 4, 5],
        [1, 2, 3, 4, 4],
        [1, 2, 3, 4, 5],
        [1, 2, 3, 4, 4],
        [1, 2, 3, 4, 6]
    ]

    result = @view.render(partial: "test/cached_set", collection: sets, cached: true)

    splited_result = result.split("\n")
    assert_equal 5, splited_result.count
    assert_equal [
      "1 | 2 | 3 | 4 | 5",
      "1 | 2 | 3 | 4 | 4",
      "1 | 2 | 3 | 4 | 5",
      "1 | 2 | 3 | 4 | 4",
      "1 | 2 | 3 | 4 | 6"
    ], splited_result
  end

  private
    def cache_key(*names, virtual_path)
      digest = ActionView::Digestor.digest name: virtual_path, format: :html, finder: @view.lookup_context, dependencies: []
      @view.combined_fragment_cache_key([ "#{virtual_path}:#{digest}", *names ])
    end
end
