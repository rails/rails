# frozen_string_literal: true

require "active_record_unit"
require "fixtures/project"
require "fixtures/developer"

class FormHelperActiveRecordTest < ActionView::TestCase
  tests ActionView::Helpers::FormHelper

  def form_for(*)
    @output_buffer = super
  end

  def setup
    @developer = Developer.new
    @developer.id   = 123
    @developer.name = "developer #123"

    @project = Project.new
    @project.id   = 321
    @project.name = "project #321"
    @project.save

    @developer.projects << @project
    @developer.save
    super
    @controller.singleton_class.include Routes.url_helpers
  end

  def teardown
    super
    Project.delete(321)
    Developer.delete(123)
  end

  Routes = ActionDispatch::Routing::RouteSet.new
  Routes.draw do
    resources :developers do
      resources :projects
    end
  end

  include Routes.url_helpers

  def test_nested_fields_for_with_child_index_option_override_on_a_nested_attributes_collection_association
    form_for(@developer) do |f|
      concat f.fields_for(:projects, @developer.projects.first, child_index: "abc") { |cf|
        concat cf.text_field(:name)
      }
    end

    expected = whole_form("/developers/123", "edit_developer_123", "edit_developer", method: "patch") do
      '<input id="developer_projects_attributes_abc_name" name="developer[projects_attributes][abc][name]" type="text" value="project #321" />' \
          '<input id="developer_projects_attributes_abc_id" name="developer[projects_attributes][abc][id]" type="hidden" value="321" />'
    end

    assert_dom_equal expected, output_buffer
  end

  private

    def hidden_fields(method = nil)
      txt = %{<input name="utf8" type="hidden" value="&#x2713;" />}.dup

      if method && !%w(get post).include?(method.to_s)
        txt << %{<input name="_method" type="hidden" value="#{method}" />}
      end

      txt
    end

    def form_text(action = "/", id = nil, html_class = nil, remote = nil, multipart = nil, method = nil)
      txt =  %{<form accept-charset="UTF-8" action="#{action}"}.dup
      txt << %{ enctype="multipart/form-data"} if multipart
      txt << %{ data-remote="true"} if remote
      txt << %{ class="#{html_class}"} if html_class
      txt << %{ id="#{id}"} if id
      method = method.to_s == "get" ? "get" : "post"
      txt << %{ method="#{method}">}
    end

    def whole_form(action = "/", id = nil, html_class = nil, options = nil)
      contents = block_given? ? yield : ""

      if options.is_a?(Hash)
        method, remote, multipart = options.values_at(:method, :remote, :multipart)
      else
        method = options
      end

      form_text(action, id, html_class, remote, multipart, method) + hidden_fields(method) + contents + "</form>"
    end
end
