require 'abstract_unit'
require 'controller/fake_models'

class FormWithHelperTest < ActionView::TestCase

  tests ActionView::Helpers::FormTagHelper

  setup do
    @post = Post.new
  end

  Routes = ActionDispatch::Routing::RouteSet.new
  Routes.draw do
    resources :posts
  end

  include Routes.url_helpers

  def test_form_with_url_and_scope
    expected = whole_form('/posts', remote: true) do
      "<label for='post_title'>The Title</label>"
    end

    actual = form_with(url: '/posts', scope: :post) do |f|
      f.label(:title, "The Title")
    end

    assert_dom_equal  expected, actual
  end

  def test_form_with_url
    expected = whole_form('/posts', remote: true) do
      "<label for='form_title'>The Title</label>"
    end
    actual = form_with(url: '/posts') do |f|
      f.label(:title, "The Title")
    end
    assert_dom_equal expected, actual
  end

  def test_form_with_model
    expected = whole_form('/posts', remote: true) do
      "<label for='post_title'>The Title</label>"
    end
    actual = form_with(model: @post) do |f|
      f.label(:title, "The Title")
    end
    assert_dom_equal expected, actual
  end

  def test_form_with_id_and_class
    expected = whole_form('/posts', remote: true, id: "post_id", class: "post_class")
    assert_dom_equal expected, form_with(model: @post, class: "post_class", id: "post_id") {}
  end

  def test_form_with_custom_attribute
    expected = whole_form('/posts', remote: true, autocomplete: "on")
    assert_dom_equal expected, form_with(model: @post, autocomplete: "on") {}
  end

  def test_form_with_data_attributes
    expected = whole_form('/posts', remote: true, "data-test": "test")
    assert_dom_equal expected, form_with(model: @post, "data-test": "test") {}
    assert_dom_equal expected, form_with(model: @post, data: {test: "test"} ) {}    
  end


  protected

    def hidden_fields(method: nil, enforce_utf8: true, **options)
      if enforce_utf8
        txt = %{<input name="utf8" type="hidden" value="&#x2713;" />}
      else
        txt = ''
      end

      if method && !%w(get post).include?(method.to_s)
        txt << %{<input name="_method" type="hidden" value="#{method}" />}
      end

      txt
    end

    def form_text(action = "/", remote: nil, multipart: nil, method: "post", **options)
      txt =  %{<form accept-charset="UTF-8" action="#{action}"}
      txt << %{ enctype="multipart/form-data"} if multipart
      txt << %{ data-remote="true"} if remote
      options.each do |attr, value|
        txt << %{ #{attr}="#{value}"}
      end
      txt << %{ method="#{method}">}
    end

    def whole_form(action = "/", method: "post", remote: nil, multipart: nil, **options, &block)
      contents = block_given? ? yield : ""
      form_tag = form_text(action, remote: remote, multipart: multipart, method: method, **options)
      form_tag + hidden_fields(options.slice :method, :enforce_utf8) + contents + "</form>"
    end

end