# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class ActionViewRailtieTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    test "render tracker is configured before eager loading" do
      make_basic_app do |app|
        app.config.load_defaults "8.1"
        app.config.eager_load = true
      end

      trackers = ActionView::DependencyTracker.instance_variable_get(:@trackers)
      erb_handler = ActionView::Template.handler_for_extension("erb")

      assert_equal :ruby, ActionView.render_tracker
      assert_equal ActionView::DependencyTracker::RubyTracker, trackers[erb_handler]
    end
  end
end
