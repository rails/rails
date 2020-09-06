# frozen_string_literal: true

require 'abstract_unit'
require 'action_view/template/handlers/erb/erubi'

class ErubiTest < ActiveSupport::TestCase
  test 'can configure bufvar' do
    template = <<~ERB
      foo

      <%= "foo".upcase %>

      <%== "foo".length %>
    ERB

    baseline = ActionView::Template::Handlers::ERB::Erubi.new(template)
    erubi = ActionView::Template::Handlers::ERB::Erubi.new(template, bufvar: 'boofer')

    assert_equal baseline.src.gsub("#{baseline.bufvar}.", 'boofer.'), erubi.src
  end
end
