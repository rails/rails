require 'abstract_unit'
require 'controller/fake_models'

class FormWithHelperTest < ActionView::TestCase

  tests ActionView::Helpers::FormTagHelper

  setup do
    @post = Post.new("Catch 22", "Joseph Heller", "The plotline follows...", 1, false, Date.new(2004, 6, 15))
    I18n.backend.store_translations 'placeholder', {
      activemodel: {
        attributes: {
          post: {
            cost: "Total cost"
          },
          :"post/cost" => {
            uk: "Pounds"
          }
        }
      },
      helpers: {
        placeholder: {
          post: {
            title: "What is this about?",
            written_on: {
              spanish: "Escrito en"
            },
          }
        }
      }
    }
  end

  Routes = ActionDispatch::Routing::RouteSet.new
  Routes.draw do
    resources :customers
    resources :posts
  end

  include Routes.url_helpers

  def test_text_field
    assert_tag_equals('<input name="post[title]" type="text" value="Catch 22" />') { |f| f.text_field("title") }
    assert_tag_equals('<input name="post[title]" type="password" value="Catch 22" />') { |f| f.password_field("title", value: @post.title) }
    assert_tag_equals('<input name="post[title]" type="password" />') { |f| f.password_field("title") }
  end

  def test_text_field_with_escapes
    @post.title = "<b>Hello World</b>"
    assert_tag_equals('<input name="post[title]" type="text" value="&lt;b&gt;Hello World&lt;/b&gt;" />') { |f| f.text_field("title") }
  end

  def test_text_field_with_html_entities
    @post.title = "The HTML Entity for & is &amp;"
    assert_tag_equals('<input name="post[title]" type="text" value="The HTML Entity for &amp; is &amp;amp;" />') { |f| f.text_field("title") }
  end

  def test_text_field_with_options
    assert_tag_equals('<input name="post[title]" size="35" type="text" value="Catch 22" />') { |f| f.text_field("title", size: 35) }
  end

  def test_text_field_assuming_size
    assert_tag_equals('<input maxlength="35" name="post[title]" size="35" type="text" value="Catch 22" />') { |f| f.text_field("title", maxlength: 35) }
  end

  def test_text_field_removing_size
    assert_tag_equals('<input maxlength="35" name="post[title]" type="text" value="Catch 22" />') { |f| f.text_field("title", maxlength: 35, size: nil) }
  end

  def test_text_field_with_nil_value
    assert_tag_equals('<input name="post[title]" type="text" />') { |f| f.text_field("title", nil) }
  end

  def test_text_field_with_nil_name
    assert_tag_equals('<input type="text" value="Catch 22" />') { |f| f.text_field("title", name: nil) }
  end

  def test_text_field_with_custom_scope
    assert_tag_equals("<input type='text' name='custom[title]' value='Catch 22'>") { |f| f.text_field :title, scope: 'custom' }
  end

  def test_text_field_with_nil_scope
    assert_tag_equals("<input type='text' name='title' value='Catch 22'>") { |f| f.text_field :title, scope: nil }
  end

  def test_text_field_with_id
    assert_tag_equals("<input type='text' name='post[title]' value='Catch 22' id='this_is_post_title'>") { |f| f.text_field :title, id: 'this_is_post_title' }
  end
  def test_text_field_with_value
    assert_tag_equals("<input type='text' name='post[title]' value='Closing Time'>") { |f| f.text_field :title, 'Closing Time' }
  end

  def test_text_field_placeholder_without_locales
    I18n.with_locale :placeholder do
      assert_tag_equals('<input name="post[body]" placeholder="Body" type="text" value="The plotline follows..." />') do |f|
        f.text_field(:body, placeholder: true)
      end
    end
  end

  def test_text_field_placeholder_with_locales
    I18n.with_locale :placeholder do
      assert_tag_equals('<input name="post[title]" placeholder="What is this about?" type="text" value="Catch 22" />') do |f|
        f.text_field(:title, placeholder: true) 
      end
    end
  end

  def test_text_field_placeholder_with_human_attribute_name
    I18n.with_locale :placeholder do
      assert_tag_equals('<input name="post[cost]" placeholder="Total cost" type="text" />') do |f|
         f.text_field(:cost, placeholder: true)
       end
    end
  end

  def test_text_field_placeholder_with_string_value
    I18n.with_locale :placeholder do
      assert_tag_equals('<input id="post_cost" name="post[cost]" placeholder="HOW MUCH?" type="text" />') do |f| 
        text_field(:post, :cost, placeholder: "HOW MUCH?")
      end
    end
  end

  def test_text_field_placeholder_with_human_attribute_name_and_value
    I18n.with_locale :placeholder do
      assert_tag_equals('<input name="post[cost]" placeholder="Pounds" type="text" />') do |f|
        f.text_field(:cost, placeholder: :uk)
      end
    end
  end

  def test_text_field_placeholder_with_locales_and_value
    I18n.with_locale :placeholder do
      assert_tag_equals('<input name="post[written_on]" placeholder="Escrito en" type="text" value="2004-06-15" />') do |f|
         f.text_field(:written_on, placeholder: :spanish)
       end
    end
  end

  def test_checkbox
    assert_tag_equals("<input name='post[secret]' type='hidden' value='0'><input name='post[secret]' type='checkbox' value='1' >") do |f|
      f.check_box(:secret)
    end
  end

  def test_checkbox_with_custom_on_off
    assert_tag_equals("<input name='post[secret]' type='hidden' value='noo'><input name='post[secret]' type='checkbox' value='yees'>") do |f|
      f.check_box(:secret, on: 'yees', off: 'noo')
    end
  end

  def test_select_with_choices_as_pairs
    categories = [%w(Volvo volvo), %w(Saab saab), %w(Mercedes mercedes)]
    expected = "<select name='post[category]'>" +
        "<option value='volvo'>Volvo</option>\n" +
        "<option value='saab'>Saab</option>\n" +
        "<option value='mercedes'>Mercedes</option>" +
      "</select>"
    assert_tag_equals(expected) { |f| f.select :category, categories }
    assert_tag_equals(expected) { |f| f.select "category", categories }
  end

  def test_select_choices_as_array
    categories = %w(volvo saab mercedes)
    expected = "<select name='post[category]'>" +
        "<option value=''></option>" +
        "<option value='volvo'>volvo</option>\n" +
        "<option value='saab'>saab</option>\n" +
        "<option value='mercedes'>mercedes</option>" +
      "</select>"
    assert_tag_equals(expected) { |f| f.select :category, categories, blank: true }
    assert_tag_equals(expected) { |f| f.select "category", categories, blank: true }
  end

  def test_collection_select
    expected = "<select name='post[author_name]'>" +
        "<option value='&lt;Abe&gt;'>&lt;Abe&gt;</option>\n" +
        "<option value='Babe'>Babe</option>\n" +
        "<option value='Cabe'>Cabe</option>" +
      "</select>"
    assert_tag_equals(expected) { |f| f.collection_select(:author_name, dummy_posts, :author_name, :author_name) }
    assert_tag_equals(expected) { |f| f.collection_select("author_name", dummy_posts, "author_name", "author_name") }
  end

  def test_form_with_url
    expected = whole_form('/posts', remote: true) do
      #TODO: label
      # "<label for='title'>The Title</label>" +
      "<input type='text' name='title'>" +
      "<textarea name='body'>\n</textarea>" +
      "<input name='commit' value='Save changes' data-disable-with='Save changes' type='submit'>"
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

  def test_form_with_url_and_scope
    expected = whole_form('/posts', remote: true) do
      "<label for='post_title'>The Title</label>" +
      "<input type='text' name='post[title]'>" +
      "<textarea name='post[body]'>\n</textarea>" +
      "<input name='commit' value='Save Post' data-disable-with='Save Post' type='submit'>"
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
      "<input type='text' name='post[title]' value='Catch 22'>" +
      "<textarea name='post[body]'>\nThe plotline follows...</textarea>" +
      "<input name='commit' value='Create Post' data-disable-with='Create Post' type='submit'>"
    end

    actual = form_with(model: @post) do |f|
      concat f.label(:title, "The Title")
      concat f.text_field :title
      concat f.text_area :body
      concat f.submit
    end

    assert_dom_equal expected, actual
  end

  def test_form_with_non_persisted_model
    customer = Customer.new("John")
    expected = whole_form('/customers', method: 'post')
    actual = form_with(model: customer)
    assert_dom_equal expected, actual
  end

  def test_form_with_persisted_model
    customer = Customer.new("John", 123)
    expected = whole_form('/customers/123', method: 'post')
    actual = form_with(model: customer)
    assert_dom_equal expected, actual
  end

  def test_form_with_custom_id_and_class
    expected = whole_form('/posts', remote: true, id: "post_id", class: "post_class")
    assert_dom_equal expected, form_with(model: @post, class: "post_class", id: "post_id")
  end

  def test_form_with_custom_attribute
    expected = whole_form('/posts', remote: true, autocomplete: "on")
    assert_dom_equal expected, form_with(model: @post, autocomplete: "on")
  end

  def test_form_with_data_attributes
    expected = whole_form('/posts', remote: true, "data-test": "test")
    assert_dom_equal expected, form_with(model: @post, "data-test": "test")
    assert_dom_equal expected, form_with(model: @post, data: {test: "test"} )
  end

  protected

    def assert_tag_equals(expected, model: @post, &actual)
      assert_dom_equal expected, fields_with(model: model, &actual)
    end

    def hidden_fields(method: nil, enforce_utf8: true, **options)
      if enforce_utf8
        txt = %{<input name="utf8" type="hidden" value="&#x2713;">}
      else
        txt = ''
      end

      if method && !%w(get post).include?(method.to_s)
        txt << %{<input name="_method" type="hidden" value="#{method}">}
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

    def whole_form(action = "/", method: "post", remote: true, multipart: nil, **options, &block)
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