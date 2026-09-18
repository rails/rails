# frozen_string_literal: true

require "isolation/abstract_unit"

class ERBCacheTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  teardown :teardown_app

  def setup
    build_app
  end

  test "loads the ERB cache during boot" do
    require "action_view/erb_compilation_cache"

    assert_called(ActionView::ERBCompilationCache, :load!, returns: {}) do
      app
    end
  end

  test "rails:cache_erb caches all Action View ERB formats" do
    app_file "app/views/pages/show.html.erb", "<p><%= message %></p>"
    app_file "app/views/pages/show.text.erb", "<%= message %>"
    app_file "app/views/pages/show.json.jbuilder", "json.message message"

    output = rails("rails:cache_erb", "RAILS_ENV=production")

    templates, entries = output.scan(/Cached (\d+) ERB templates in (\d+) entries\./).first.map(&:to_i)
    assert_operator templates, :>=, 2
    assert_operator entries, :>=, 1
    assert_operator entries, :<=, templates
    cache_path = app_path("tmp/cache/action_view/erb")
    assert_equal ["data.json"], Dir.children(cache_path)
  end
end
