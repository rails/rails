# frozen_string_literal: true

require "isolation/abstract_unit"

class HerbCheckerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  teardown :teardown_app

  def setup
    build_app
  end

  def boot(env = "development")
    app(env)
  end

  def check
    require "action_view/herb_checker"

    ActionView::HerbChecker.check(Rails.root)
  end

  test "returns an empty list for a default application" do
    boot

    assert_empty check
  end

  test "reports templates that fail to compile through Herb, including variants and locales" do
    app_file "app/views/pages/broken.html.erb", "<div><%= hello %>"
    app_file "app/views/pages/broken.html+phone.erb", "<div><%= hello %>"
    app_file "app/views/pages/broken.fr.html.erb", "<div><%= hello %>"

    boot

    failures = check

    assert_equal [
      "app/views/pages/broken.fr.html.erb",
      "app/views/pages/broken.html+phone.erb",
      "app/views/pages/broken.html.erb",
    ], failures.map(&:path)
    assert_kind_of Herb::Engine::CompilationError, failures.first.error
  end

  test "reports templates Herb rejects for an ERB output tag in attribute position" do
    app_file "app/views/pages/unsafe.html.erb", "<div <%= attributes %>>Hello</div>"

    boot

    failures = check

    assert_equal ["app/views/pages/unsafe.html.erb"], failures.map(&:path)
    assert_kind_of Herb::Engine::SecurityError, failures.first.error
  end

  test "does not report templates that compile through Herb, including variants and locales" do
    app_file "app/views/pages/show.html.erb", <<~ERB
      <h1><%= @page.title %></h1>

      <% if @page.published? %>
        <ul class="notes">
          <% @page.notes.each do |note| %>
            <li id="note_<%= note.id %>"><%= note.body %></li>
          <% end %>
        </ul>
      <% end %>

      <img src="<%= @page.image_url %>" alt="">
      <br>

      <%= render "pages/footer" %>
    ERB
    app_file "app/views/pages/_footer.html.erb", "<footer><%= Time.current.year %></footer>"
    app_file "app/views/pages/show.html+phone.erb", "<div><%= @page.title %></div>"
    app_file "app/views/pages/show.fr.html.erb", "<div><%= @page.title %></div>"

    boot

    assert_empty check
  end

  test "skips templates that are not HTML+ERB" do
    app_file "app/views/notes/export.text.erb", "for (i = 0; i<len; i++)"
    app_file "app/views/notes/plain.erb", "for (i = 0; i<len; i++)"

    boot

    assert_empty check
  end

  test "reports HTML+ERB templates outside of app/views" do
    app_file "lib/templates/card.html.erb", "<div><%= title %>"
    app_file "lib/templates/card.html+phone.erb", "<div><%= title %>"
    app_file "lib/templates/card.text.erb", "for (i = 0; i<len; i++)"

    boot

    assert_equal [
      "lib/templates/card.html+phone.erb",
      "lib/templates/card.html.erb",
    ], check.map(&:path)
  end

  test "skips templates excluded by Herb's default configuration" do
    app_file "vendor/gems/broken.html.erb", "<div><%= hello %>"
    app_file "node_modules/pkg/broken.html.erb", "<div><%= hello %>"
    app_file "tmp/broken.html.erb", "<div><%= hello %>"

    boot

    assert_empty check
  end

  test "skips templates excluded by the application's .herb.yml" do
    app_file ".herb.yml", <<~YAML
      files:
        exclude:
          - "lib/templates/**/*"
    YAML
    app_file "lib/templates/card.html.erb", "<div><%= title %>"

    boot

    assert_empty check
  end
end
