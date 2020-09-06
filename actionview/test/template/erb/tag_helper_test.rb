# frozen_string_literal: true

require 'abstract_unit'
require 'template/erb/helper'

module ERBTest
  class TagHelperTest < BlockTestCase
    test 'percent equals works for content_tag and does not require parenthesis on method call' do
      assert_equal '<div>Hello world</div>', render_content('content_tag :div', 'Hello world')
    end

    test 'percent equals works for javascript_tag' do
      expected_output = "<script>\n//<![CDATA[\nalert('Hello')\n//]]>\n</script>"
      assert_equal expected_output, render_content('javascript_tag', "alert('Hello')")
    end

    test 'percent equals works for javascript_tag with options' do
      expected_output = "<script id=\"the_js_tag\">\n//<![CDATA[\nalert('Hello')\n//]]>\n</script>"
      assert_equal expected_output, render_content("javascript_tag(:id => 'the_js_tag')", "alert('Hello')")
    end

    test 'percent equals works with form tags' do
      expected_output = %r{<form.*action="/foo".*method="post">.*hello*</form>}
      assert_match expected_output, render_content("form_tag('/foo')", "<%= 'hello' %>")
    end

    test 'percent equals works with fieldset tags' do
      expected_output = '<fieldset><legend>foo</legend>hello</fieldset>'
      assert_equal expected_output, render_content("field_set_tag('foo')", "<%= 'hello' %>")
    end
  end
end
