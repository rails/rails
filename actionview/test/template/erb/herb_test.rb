# frozen_string_literal: true

require "abstract_unit"
require "action_view/template/handlers/erb/herb"

class HerbTest < ActiveSupport::TestCase
  test "can configure bufvar" do
    template = <<~ERB
      foo

      <%= "foo".upcase %>

      <%== "foo".length %>
    ERB

    baseline = ActionView::Template::Handlers::ERB::Herb.new(template)
    herb = ActionView::Template::Handlers::ERB::Herb.new(template, bufvar: "boofer")

    assert_equal baseline.src.gsub(baseline.bufvar, "boofer"), herb.src
  end

  test "renders the same output as Erubi" do
    templates = [
      "<p>plain</p>\n",
      "<p><%= name %></p>\n",
      "<p><%== name %></p>\n",
      "<p><%= safe_name %></p>\n",
      "foo\n\n<%= name %>\n\nbar\n",
      "<%# a comment %>\n<div>content</div>\n",
      "<% if name %>\n  <span><%= name %></span>\n<% else %>\n  <span>anonymous</span>\n<% end %>\n",
      "<ul>\n<% 3.times do |i| %>\n  <li><%= i %></li>\n<% end %>\n</ul>\n",
      "<input type=\"text\" name=\"<%= name %>\">\n",
      "<script>\n  var name = \"<%= name %>\";\n</script>\n",
      "<a href=\"#anchor\"><%= \"#anchor\" %></a>\n",
      "<p><%= <<~TXT\n  hello\nTXT\n%></p>\n"
    ]

    templates.each do |template|
      assert_equal render_with(erubi, template), render_with(herb, template), "expected Herb and Erubi to render the same output for #{template.inspect}"
    end
  end

  test "renders whitespace trimming tags the same as Erubi" do
    templates = [
      "<% value = 1 -%>\n<p><%= value %></p>\n",
      "text\n  <%- value = 1 %>\n<p><%= value %></p>\n",
      "<div>\n  <% if name -%>\n    <span>x</span>\n  <% end -%>\n</div>\n"
    ]

    templates.each do |template|
      assert_equal render_with(erubi, template), render_with(herb, template), "expected Herb and Erubi to trim the same way for #{template.inspect}"
    end
  end

  test "renders multi-line code tags the same as Erubi" do
    template = <<~ERB
      <table>
       <tbody>
        <% i = 0
           list.each_with_index do |item, i| %>
        <tr>
         <td><%= i + 1 %></td>
         <td><%== item %></td>
        </tr>
       <% end %>
       </tbody>
      </table>
      <%== i + 1 %>
    ERB

    assert_equal render_with(erubi, template), render_with(herb, template)
  end

  test "renders case expressions the same as Erubi" do
    template = <<~ERB
      <% case name %>
      <% when "AT&T" %>
        <p>att</p>
      <% else %>
        <p>other</p>
      <% end %>
    ERB

    assert_equal render_with(erubi, template), render_with(herb, template)
  end

  test "renders block expressions the same as Erubi" do
    template = "<%= wrapper do %>\n  <p>hi</p>\n<% end %>\n"

    assert_equal render_with(erubi, template), render_with(herb, template)
  end

  test "renders escaped block expressions the same as Erubi" do
    template = "<%== wrapper do %>\n  <p>hi</p>\n<% end %>\n"

    assert_equal render_with(erubi, template), render_with(herb, template)
  end

  test "compiles expressions containing Ruby comments" do
    template = "<p><%= name # visible name %></p>\n"

    assert_equal "<p>AT&amp;T</p>\n", render_with(herb, template)
  end

  test "renders the same output as Erubi with the escape option" do
    template = "Hello <%= name %> <%== name %>\n"

    assert_equal render_with(erubi, template, escape: true), render_with(herb, template, escape: true)
    assert_equal "Hello AT&T AT&T\n", render_with(herb, template, escape: true)
  end

  test "renders the render annotation preamble and postamble the same as Erubi" do
    template = "<p><%= name %></p>\n"
    options = {
      preamble: "@output_buffer.safe_append='<!-- BEGIN app/views/users/show.html.erb\n-->';",
      postamble: "@output_buffer.safe_append='<!-- END app/views/users/show.html.erb -->';@output_buffer"
    }

    herb_output = render_with(herb, template, options)

    assert_equal render_with(erubi, template, options), herb_output
    assert_includes herb_output, "<!-- BEGIN app/views/users/show.html.erb"
    assert_includes herb_output, "<!-- END app/views/users/show.html.erb -->"
  end

  test "ties template literal freezing to frozen_string_literal like Erubi" do
    template = "<p><%= name %></p>\n"

    assert_includes herb.new(template).src, ".freeze"

    original = ActionView::Template.frozen_string_literal
    ActionView::Template.frozen_string_literal = true

    assert_no_match(/\.freeze/, herb.new(template).src)
  ensure
    ActionView::Template.frozen_string_literal = original
  end

  test "reports runtime errors at the same template line as Erubi" do
    template = "<div>\n  <p>ok</p>\n  <% raise \"boom\" %>\n</div>\n"

    herb_line = error_line(herb, template)

    assert_equal error_line(erubi, template), herb_line
    assert_equal 3, herb_line
  end

  test "escapes attribute values through the output buffer only" do
    template = "<input type=\"text\" name=\"<%= name %>\">\n"
    source = herb.new(template).src

    assert_no_match(/Herb::Engine/, source)
    assert_equal "<input type=\"text\" name=\"AT&amp;T\">\n", render_with(herb, template)
  end

  private
    def erubi
      ActionView::Template::Handlers::ERB::Erubi
    end

    def herb
      ActionView::Template::Handlers::ERB::Herb
    end

    def build_context
      context = Object.new
      context.instance_variable_set(:@output_buffer, ActionView::OutputBuffer.new)
      context.define_singleton_method(:name) { "AT&T" }
      context.define_singleton_method(:safe_name) { "<b>safe</b>".html_safe }
      context.define_singleton_method(:list) { ["a&b", "c"] }
      context.define_singleton_method(:wrapper) { |&block| @output_buffer.capture(&block).upcase }
      context
    end

    def render_with(implementation, template, options = {})
      build_context.instance_eval(implementation.new(template, options).src).to_s
    end

    def error_line(implementation, template)
      build_context.instance_eval(implementation.new(template).src, "inline template")
      flunk "expected template to raise"
    rescue RuntimeError => error
      error.backtrace_locations.find { |location| location.path == "inline template" }.lineno
    end
end
