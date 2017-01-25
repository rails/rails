require "abstract_unit"

module ERBTest
  class DeprecatedErubisImplementationTest < ActionView::TestCase
    test "Erubis implementation is deprecated" do
      assert_deprecated "ActionView::Template::Handlers::Erubis is deprecated and will be removed from Rails 5.2. Switch to ActionView::Template::Handlers::ERB::Erubi instead." do
        assert_equal "ActionView::Template::Handlers::ERB::Erubis", ActionView::Template::Handlers::Erubis.to_s
      end
    end
  end
end
