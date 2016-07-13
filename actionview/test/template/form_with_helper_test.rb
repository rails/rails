require 'abstract_unit'
require 'controller/fake_models'

class FormWithHelperTest < ActionView::TestCase

  tests ActionView::Helpers::FormTagHelper

  setup do
    @post = Post.new("Catch 22", "Joseph Heller", "The plotline follows the airmen of the 256th Squadron...", 1)
  end

  Routes = ActionDispatch::Routing::RouteSet.new
  Routes.draw do
    resources :posts
  end

  include Routes.url_helpers

  def test_form_with_url
    expected = whole_form('/posts', remote: true) do
      #TODO: label
      # "<label for='title'>The Title</label>" +
      "<input type='text' name='title' />" +
      "<textarea name='body'>\n</textarea>" +
      "<input name='commit' value='Submit' data-disable-with='Submit' type='submit' />"      
    end
    actual = form_with(url: '/posts') do |f|
      #TODO: label
      # concat f.label(:title, "The Title")
      concat f.text_field :title
      concat f.text_area :body
      concat f.submit
    end
    assert_dom_equal expected, actual
  end

  def test_form_with_select_choices_as_pairs
    expected = whole_form('/posts', remote: true) do
      "<select name='category'>" +
        "<option value='volvo'>Volvo</option>\n" +
        "<option value='saab'>Saab</option>\n" +
        "<option value='mercedes'>Mercedes</option>" +
      "</select>"
    end
    categories = [%w(Volvo volvo), %w(Saab saab), %w(Mercedes mercedes)]
    actual = form_with(url: '/posts') do |f|
      f.select :category, categories
    end
    assert_dom_equal expected, actual
  end

  def test_form_with_select_choices_as_array
    expected = whole_form('/posts', remote: true) do
      "<select name='category'>" +
        "<option value=''></option>" +
        "<option value='volvo'>volvo</option>\n" +
        "<option value='saab'>saab</option>\n" +
        "<option value='mercedes'>mercedes</option>" +
      "</select>"
    end
    categories = %w(volvo saab mercedes)
    actual = form_with(url: '/posts') do |f|
      f.select :category, categories, blank: true
    end
    assert_dom_equal expected, actual
  end

  def test_form_with_url_and_collection_select
    expected = whole_form('/posts', remote: true) do
      "<select name='author_name'>" +
        "<option value='&lt;Abe&gt;'>&lt;Abe&gt;</option>\n" +
        "<option value='Babe'>Babe</option>\n" +
        "<option value='Cabe'>Cabe</option>" +
      "</select>"
    end
    actual = form_with(url: '/posts') do |f|
      f.collection_select("author_name", dummy_posts, "author_name", "author_name")
    end
    assert_dom_equal expected, actual
  end

  def test_form_with_model_and_collection_select
    expected = whole_form('/posts', remote: true) do
      "<select name='post[author_name]'>" +
        "<option value='&lt;Abe&gt;'>&lt;Abe&gt;</option>\n" +
        "<option value='Babe'>Babe</option>\n" +
        "<option value='Cabe'>Cabe</option>" +
      "</select>"
    end
    actual = form_with(model: @post) do |f|
      f.collection_select("author_name", dummy_posts, "author_name", "author_name")
    end
    assert_dom_equal expected, actual
  end

  def test_form_with_url_and_scope
    expected = whole_form('/posts', remote: true) do
      "<label for='post_title'>The Title</label>" +
      "<input type='text' name='post[title]' />" +
      "<textarea name='post[body]'>\n</textarea>" +
      "<input name='commit' value='Save Post' data-disable-with='Save Post' type='submit' />"
    end

    actual = form_with(url: '/posts', scope: :post) do |f|
      concat f.label(:title, "The Title")
      concat f.text_field :title
      concat f.text_area :body
      concat f.submit
    end

    assert_dom_equal  expected, actual
  end

  def test_form_with_model
    expected = whole_form('/posts', remote: true) do
      "<label for='post_title'>The Title</label>" +
      "<input type='text' name='post[title]' value='Catch 22' />" +
      "<textarea name='post[body]'>\nThe plotline follows the airmen of the 256th Squadron...</textarea>" +
      "<input name='commit' value='Create Post' data-disable-with='Create Post' type='submit' />"
    end

    actual = form_with(model: @post) do |f|
      concat f.label(:title, "The Title")
      concat f.text_field :title
      concat f.text_area :body
      concat f.submit
    end

    assert_dom_equal expected, actual
  end

  def test_form_with_text_field_with_custom_scope
    assert_tag_equals("<input type='text' name='custom[title]' value='Catch 22' />") { |f| f.text_field :title, scope: 'custom' }
  end

  def test_form_with_text_field_with_nil_scope
    assert_tag_equals("<input type='text' name='title' value='Catch 22' />") { |f| f.text_field :title, scope: nil }
  end

  def test_form_with_text_field_with_id
    assert_tag_equals("<input type='text' name='post[title]' value='Catch 22' id='this_is_post_title'/>") { |f| f.text_field :title, id: 'this_is_post_title' }
  end
  def test_form_with_text_field_with_value
    assert_tag_equals("<input type='text' name='post[title]' value='Closing Time' />") { |f| f.text_field :title, 'Closing Time' }
  end

  def test_form_with_checkbox
    assert_tag_equals("<input name='post[secret]' type='hidden' value='0' /><input name='post[secret]' checked='checked' type='checkbox' value='1' />") do |f|
      f.check_box(:secret)
    end
    assert_tag_equals("<input name='post[secret]' type='hidden' value='noo' /><input name='post[secret]' type='checkbox' value='yees' />") do |f|
      f.check_box(:secret, on: 'yees', off: 'noo')
    end
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

    def assert_tag_equals(expected, &actual)
      assert_dom_equal whole_form('/posts', remote: true) { expected }, form_with(model: @post, &actual)
    end

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

    def dummy_posts
      [ Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
        Post.new("Babe went home", "Babe", "To a little house", "shh!"),
        Post.new("Cabe went home", "Cabe", "To a little house", "shh!") ]
    end


end