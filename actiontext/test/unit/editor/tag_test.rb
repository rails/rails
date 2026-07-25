# frozen_string_literal: true

require "test_helper"

module ActionText
  class Editor::TagTest < ActionView::TestCase
    class TagSubclassCallingSuper < Editor::Tag
      def render_in(view_context, ...)
        super
      end
    end

    test "subclasses can call super from #render_in" do
      assert_nothing_raised do
        render(TagSubclassCallingSuper.new("trix"))
      end
    end
  end
end
