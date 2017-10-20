# frozen_string_literal: true

require "abstract_unit"
require "template/erb/helper"

module ERBTest
  class TagHelperTest < BlockTestCase
    test "form_for works" do
      output = render_content "form_for(:staticpage, :url => {:controller => 'blah', :action => 'update'})", ""
      assert_match %r{<form.*action="/blah/update".*method="post">.*</form>}, output
    end
  end
end
