# frozen_string_literal: true

require "abstract_unit"

class FormTagHelperTest < ActionView::TestCase
  include RenderERBUtils

  tests ActionView::Helpers::FormTagHelper

  class WithActiveStorageRoutesControllers < ActionController::Base
    test_routes do
      post "/rails/active_storage/direct_uploads" => "active_storage/direct_uploads#create", as: :rails_direct_uploads
    end

    def url_options
      { host: "testtwo.host" }
    end
  end

  def setup
    super
    @controller = BasicController.new
  end

  def hidden_fields(options = {})
    method = options[:method]
    enforce_utf8 = options.fetch(:enforce_utf8, true)

    (+"").tap do |txt|
      if enforce_utf8
        txt << %{<input name="utf8" type="hidden" value="&#x2713;" autocomplete="off" />}
      end

      if method && !%w(get post).include?(method.to_s)
        txt << %{<input name="_method" type="hidden" value="#{method}" autocomplete="off" />}
      end
    end
  end

  def form_text(action = "http://www.example.com", options = {})
    remote, enctype, html_class, id, method = options.values_at(:remote, :enctype, :html_class, :id, :method)

    method = method.to_s == "get" ? "get" : "post"

    txt =  +%{<form accept-charset="UTF-8"} + (action ? %{ action="#{action}"} : "")
    txt << %{ enctype="multipart/form-data"} if enctype
    txt << %{ data-remote="true"} if remote
    txt << %{ class="#{html_class}"} if html_class
    txt << %{ id="#{id}"} if id
    txt << %{ method="#{method}">}
  end

  def whole_form(action = "http://www.example.com", options = {})
    out = form_text(action, options) + hidden_fields(options)

    if block_given?
      out << yield << "</form>"
    end

    out
  end

  def url_for(options)
    if options.is_a?(Hash)
      "http://www.example.com"
    else
      super
    end
  end

  VALID_HTML_ID = /^[A-Za-z][-_:.A-Za-z0-9]*$/ # see http://www.w3.org/TR/html4/types.html#type-name

  def test_checkbox_tag
    actual = checkbox_tag "admin"
    expected = %(<input id="admin" name="admin" type="checkbox" value="1" />)
    assert_dom_equal expected, actual
  end

  def test_checkbox_tag_disabled
    actual = checkbox_tag "admin", "1", false, disabled: true
    expected = %(<input id="admin" disabled="disabled" name="admin" type="checkbox" value="1" />)
    assert_dom_equal expected, actual
  end

  def test_checkbox_tag_default_checked
    actual = checkbox_tag "admin", "1", true
    expected = %(<input id="admin" checked="checked" name="admin" type="checkbox" value="1" />)
    assert_dom_equal expected, actual
  end

  def test_checkbox_tag_checked_kwarg_true
    actual = checkbox_tag "admin", "yes", checked: true
    expected = %(<input id="admin" checked="checked" name="admin" type="checkbox" value="yes" />)
    assert_dom_equal expected, actual
  end

  def test_checkbox_tag_checked_kwarg_false
    actual = checkbox_tag "admin", "1", checked: false
    expected = %(<input id="admin" name="admin" type="checkbox" value="1" />)
    assert_dom_equal expected, actual
  end

  def test_checkbox_tag_checked_kwarg_false_and_disabled
    actual = checkbox_tag "admin", "1", checked: false, disabled: true
    expected = %(<input id="admin" name="admin" type="checkbox" value="1" disabled="disabled" />)
    assert_dom_equal expected, actual
  end

  def test_checkbox_tag_checked_kwarg_true_value_argument_skipped
    actual = checkbox_tag "admin", checked: true
    expected = %(<input id="admin" checked="checked" name="admin" type="checkbox" value="1" />)
    assert_dom_equal expected, actual
  end

  def test_checkbox_tag_value_kwarg
    actual = checkbox_tag "admin", value: "0", checked: true
    expected = %(<input id="admin" name="admin" type="checkbox" value="0" checked="checked" />)
    assert_dom_equal expected, actual
  end

  def test_checkbox_tag_id_sanitized
    label_elem = root_elem(checkbox_tag("project[2][admin]"))
    assert_match VALID_HTML_ID, label_elem["id"]
  end

  def test_form_tag
    actual = form_tag
    expected = whole_form
    assert_dom_equal expected, actual
  end

  def test_form_tag_multipart
    actual = form_tag({}, { "multipart" => true })
    expected = whole_form("http://www.example.com", enctype: true)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_method_patch
    actual = form_tag({}, { method: :patch })
    expected = whole_form("http://www.example.com", method: :patch)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_method_put
    actual = form_tag({}, { method: :put })
    expected = whole_form("http://www.example.com", method: :put)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_method_delete
    actual = form_tag({}, { method: :delete })

    expected = whole_form("http://www.example.com", method: :delete)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_remote
    actual = form_tag({}, { remote: true })

    expected = whole_form("http://www.example.com", remote: true)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_remote_false
    actual = form_tag({}, { remote: false })

    expected = whole_form
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_false_url_for_options
    actual = form_tag(false)

    expected = whole_form(false)
    assert_dom_equal expected, actual
  end

  def test_form_tag_with_false_action
    actual = form_tag({}, action: false)

    expected = whole_form(false)
    assert_dom_equal expected, actual
  end

  def test_form_tag_enforce_utf8_true
    actual = form_tag({}, { enforce_utf8: true })
    expected = whole_form("http://www.example.com", enforce_utf8: true)
    assert_dom_equal expected, actual
    assert_predicate actual, :html_safe?
  end

  def test_form_tag_enforce_utf8_false
    actual = form_tag({}, { enforce_utf8: false })
    expected = whole_form("http://www.example.com", enforce_utf8: false)
    assert_dom_equal expected, actual
    assert_predicate actual, :html_safe?
  end

  def test_form_tag_default_enforce_utf8_false
    with_default_enforce_utf8 false do
      actual = form_tag({})
      expected = whole_form("http://www.example.com", enforce_utf8: false)
      assert_dom_equal expected, actual
      assert_predicate actual, :html_safe?
    end
  end

  def test_form_tag_default_enforce_utf8_true
    with_default_enforce_utf8 true do
      actual = form_tag({})
      expected = whole_form("http://www.example.com", enforce_utf8: true)
      assert_dom_equal expected, actual
      assert_predicate actual, :html_safe?
    end
  end

  def test_form_tag_with_block_in_erb
    output_buffer = render_erb("<%= form_tag('http://www.example.com') do %>Hello world!<% end %>")

    expected = whole_form { "Hello world!" }
    assert_dom_equal expected, output_buffer
  end

  def test_form_tag_with_block_and_method_in_erb
    output_buffer = render_erb("<%= form_tag('http://www.example.com', :method => :put) do %>Hello world!<% end %>")

    expected = whole_form("http://www.example.com", method: "put") do
      "Hello world!"
    end

    assert_dom_equal expected, output_buffer
  end

  def test_field_id_without_suffixes_or_index
    value = field_id(:post, :title)

    assert_equal "post_title", value
  end

  def test_field_id_with_suffixes
    value = field_id(:post, :title, :error)

    assert_equal "post_title_error", value
  end

  def test_field_id_with_suffixes_and_index
    value = field_id(:post, :title, :error, index: 1)

    assert_equal "post_1_title_error", value
  end

  def test_field_id_with_nested_object_name
    value = field_id("post[author]", :name)

    assert_equal "post_author_name", value
  end

  def test_field_name_with_nil_object_name
    value = field_name(nil, :title)

    assert_equal "title", value
  end

  def test_field_name_with_blank_object_name
    value = field_name("", :title)

    assert_equal "title", value
  end

  def test_field_name_without_object_name_and_multiple
    value = field_name("", :title, multiple: true)

    assert_equal "title[]", value
  end

  def test_field_name_without_method_names_or_multiple_or_index
    value = field_name(:post, :title)

    assert_equal "post[title]", value
  end

  def test_field_name_without_method_names_and_multiple
    value = field_name(:post, :title, multiple: true)

    assert_equal "post[title][]", value
  end

  def test_field_name_without_method_names_and_index
    value = field_name(:post, :title, index: 1)

    assert_equal "post[1][title]", value
  end

  def test_field_name_without_method_names_and_index_and_multiple
    value = field_name(:post, :title, index: 1, multiple: true)

    assert_equal "post[1][title][]", value
  end

  def test_field_name_with_method_names
    value = field_name(:post, :title, :subtitle)

    assert_equal "post[title][subtitle]", value
  end

  def test_field_name_with_method_names_and_index
    value = field_name(:post, :title, :subtitle, index: 1)

    assert_equal "post[1][title][subtitle]", value
  end

  def test_field_name_with_method_names_and_multiple
    value = field_name(:post, :title, :subtitle, multiple: true)

    assert_equal "post[title][subtitle][]", value
  end

  def test_field_name_with_method_names_and_multiple_and_index
    value = field_name(:post, :title, :subtitle, index: 1, multiple: true)

    assert_equal "post[1][title][subtitle][]", value
  end

  def test_hidden_field_tag
    actual = hidden_field_tag "id", 3
    expected = %(<input id="id" name="id" type="hidden" value="3" autocomplete="off" />)
    assert_dom_equal expected, actual
  end

  def test_hidden_field_tag_with_autocomplete
    actual = hidden_field_tag "username", "me@example.com", autocomplete: "username"
    expected = %(<input id="username" name="username" type="hidden" value="me@example.com" autocomplete="username" />)
    assert_dom_equal expected, actual
  end

  def test_hidden_field_tag_with_autocomplete_false
    actual = hidden_field_tag "id", 3, autocomplete: nil
    expected = %(<input id="id" name="id" type="hidden" value="3" />)
    assert_dom_equal expected, actual
  end

  def test_hidden_field_tag_id_sanitized
    input_elem = root_elem(hidden_field_tag("item[][title]"))
    assert_match VALID_HTML_ID, input_elem["id"]
  end

  def test_file_field_tag
    assert_dom_equal "<input name=\"picsplz\" type=\"file\" id=\"picsplz\" />", file_field_tag("picsplz")
  end

  def test_file_field_tag_with_options
    assert_dom_equal "<input name=\"picsplz\" type=\"file\" id=\"picsplz\" class=\"pix\"/>", file_field_tag("picsplz", class: "pix")
  end

  def test_file_field_tag_with_direct_upload_when_rails_direct_uploads_url_is_not_defined
    assert_dom_equal(
      "<input name=\"picsplz\" type=\"file\" id=\"picsplz\" class=\"pix\"/>",
      file_field_tag("picsplz", class: "pix", direct_upload: true)
    )
  end

  def test_file_field_tag_with_direct_upload_when_rails_direct_uploads_url_is_defined
    @controller = WithActiveStorageRoutesControllers.new

    assert_dom_equal(
      "<input name=\"picsplz\" type=\"file\" id=\"picsplz\" class=\"pix\" data-direct-upload-url=\"http://testtwo.host/rails/active_storage/direct_uploads\"/>",
      file_field_tag("picsplz", class: "pix", direct_upload: true)
    )
  end

  def test_file_field_tag_with_direct_upload_dont_mutate_arguments
    original_options = { class: "pix", direct_upload: true }

    assert_dom_equal(
      "<input name=\"picsplz\" type=\"file\" id=\"picsplz\" class=\"pix\"/>",
      file_field_tag("picsplz", original_options)
    )

    assert_equal({ class: "pix", direct_upload: true }, original_options)
  end

  def test_password_field_tag
    actual = password_field_tag
    expected = %(<input id="password" name="password" type="password" />)
    assert_dom_equal expected, actual
  end

  def test_multiple_field_tags_with_same_options
    options = { class: "important" }
    assert_dom_equal %(<input name="title" type="file" id="title" class="important"/>), file_field_tag("title", options)
    assert_dom_equal %(<input type="password" name="title" id="title" value="Hello!" class="important" />), password_field_tag("title", "Hello!", options)
    assert_dom_equal %(<input type="text" name="title" id="title" value="Hello!" class="important" />), text_field_tag("title", "Hello!", options)
  end

  def test_radio_button_tag
    actual = radio_button_tag "people", "david"
    expected = %(<input id="people_david" name="people" type="radio" value="david" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag("num_people", 5)
    expected = %(<input id="num_people_5" name="num_people" type="radio" value="5" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag("gender", "m") + radio_button_tag("gender", "f")
    expected = %(<input id="gender_m" name="gender" type="radio" value="m" /><input id="gender_f" name="gender" type="radio" value="f" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag("opinion", "-1") + radio_button_tag("opinion", "1")
    expected = %(<input id="opinion_-1" name="opinion" type="radio" value="-1" /><input id="opinion_1" name="opinion" type="radio" value="1" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag("person[gender]", "m")
    expected = %(<input id="person_gender_m" name="person[gender]" type="radio" value="m" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag("ctrlname", "apache2.2")
    expected = %(<input id="ctrlname_apache2.2" name="ctrlname" type="radio" value="apache2.2" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag "people", "david", true
    expected = %(<input id="people_david" name="people" type="radio" value="david" checked="checked" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag "people", "david", false
    expected = %(<input id="people_david" name="people" type="radio" value="david" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag "people", "david", false, disabled: true
    expected = %(<input id="people_david" name="people" type="radio" value="david" disabled="disabled" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag "people", "david", checked: true
    expected = %(<input id="people_david" name="people" type="radio" value="david" checked="checked" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag "people", "david", checked: false
    expected = %(<input id="people_david" name="people" type="radio" value="david" />)
    assert_dom_equal expected, actual

    actual = radio_button_tag "people", "david", checked: false, disabled: true
    expected = %(<input id="people_david" name="people" type="radio" value="david" disabled="disabled" />)
    assert_dom_equal expected, actual
  end

  def test_select_tag
    actual = select_tag "people", raw("<option>david</option>")
    expected = %(<select id="people" name="people"><option>david</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_with_multiple
    actual = select_tag "colors", raw("<option>Red</option><option>Blue</option><option>Green</option>"), multiple: true
    expected = %(<select id="colors" multiple="multiple" name="colors[]"><option>Red</option><option>Blue</option><option>Green</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_disabled
    actual = select_tag "places", raw("<option>Home</option><option>Work</option><option>Pub</option>"), disabled: true
    expected = %(<select id="places" disabled="disabled" name="places"><option>Home</option><option>Work</option><option>Pub</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_id_sanitized
    input_elem = root_elem(select_tag("project[1]people", "<option>david</option>"))
    assert_match VALID_HTML_ID, input_elem["id"]
  end

  def test_select_tag_with_include_blank
    actual = select_tag "places", raw("<option>Home</option><option>Work</option><option>Pub</option>"), include_blank: true
    expected = %(<select id="places" name="places"><option value="" label=" "></option><option>Home</option><option>Work</option><option>Pub</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_with_include_blank_doesnt_change_options
    options = { include_blank: true, prompt: "string" }
    expected_options = options.dup
    select_tag "places", raw("<option>Home</option><option>Work</option><option>Pub</option>"), options
    expected_options.each { |k, v| assert_equal v, options[k] }
  end

  def test_select_tag_with_include_blank_false
    actual = select_tag "places", raw("<option>Home</option><option>Work</option><option>Pub</option>"), include_blank: false
    expected = %(<select id="places" name="places"><option>Home</option><option>Work</option><option>Pub</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_with_include_blank_string
    actual = select_tag "places", raw("<option>Home</option><option>Work</option><option>Pub</option>"), include_blank: "Choose"
    expected = %(<select id="places" name="places"><option value="">Choose</option><option>Home</option><option>Work</option><option>Pub</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_with_prompt
    actual = select_tag "places", raw("<option>Home</option><option>Work</option><option>Pub</option>"), prompt: "string"
    expected = %(<select id="places" name="places"><option value="">string</option><option>Home</option><option>Work</option><option>Pub</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_escapes_prompt
    actual = select_tag "places", raw("<option>Home</option><option>Work</option><option>Pub</option>"), prompt: "<script>alert(1337)</script>"
    expected = %(<select id="places" name="places"><option value="">&lt;script&gt;alert(1337)&lt;/script&gt;</option><option>Home</option><option>Work</option><option>Pub</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_with_prompt_and_include_blank
    actual = select_tag "places", raw("<option>Home</option><option>Work</option><option>Pub</option>"), prompt: "string", include_blank: true
    expected = %(<select name="places" id="places"><option value="">string</option><option value="" label=" "></option><option>Home</option><option>Work</option><option>Pub</option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_with_nil_option_tags_and_include_blank
    actual = select_tag "places", nil, include_blank: true
    expected = %(<select id="places" name="places"><option value="" label=" "></option></select>)
    assert_dom_equal expected, actual
  end

  def test_select_tag_with_nil_option_tags_and_prompt
    actual = select_tag "places", nil, prompt: "string"
    expected = %(<select id="places" name="places"><option value="">string</option></select>)
    assert_dom_equal expected, actual
  end

  def test_textarea_tag_size_string
    actual = textarea_tag "body", "hello world", "size" => "20x40"
    expected = %(<textarea cols="20" id="body" name="body" rows="40">\nhello world</textarea>)
    assert_dom_equal expected, actual
  end

  def test_textarea_tag_size_symbol
    actual = textarea_tag "body", "hello world", size: "20x40"
    expected = %(<textarea cols="20" id="body" name="body" rows="40">\nhello world</textarea>)
    assert_dom_equal expected, actual
  end

  def test_textarea_tag_should_disregard_size_if_its_given_as_an_integer
    actual = textarea_tag "body", "hello world", size: 20
    expected = %(<textarea id="body" name="body">\nhello world</textarea>)
    assert_dom_equal expected, actual
  end

  def test_textarea_tag_id_sanitized
    input_elem = root_elem(textarea_tag("item[][description]"))
    assert_match VALID_HTML_ID, input_elem["id"]
  end

  def test_textarea_tag_escape_content
    actual = textarea_tag "body", "<b>hello world</b>", size: "20x40"
    expected = %(<textarea cols="20" id="body" name="body" rows="40">\n&lt;b&gt;hello world&lt;/b&gt;</textarea>)
    assert_dom_equal expected, actual
  end

  def test_textarea_tag_unescaped_content
    actual = textarea_tag "body", "<b>hello world</b>", size: "20x40", escape: false
    expected = %(<textarea cols="20" id="body" name="body" rows="40">\n<b>hello world</b></textarea>)
    assert_dom_equal expected, actual
  end

  def test_textarea_tag_unescaped_nil_content
    actual = textarea_tag "body", nil, escape: false
    expected = %(<textarea id="body" name="body">\n</textarea>)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag
    actual = text_field_tag "title", "Hello!"
    expected = %(<input id="title" name="title" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_class_string
    actual = text_field_tag "title", "Hello!", "class" => "admin"
    expected = %(<input class="admin" id="title" name="title" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_size_symbol
    actual = text_field_tag "title", "Hello!", size: 75
    expected = %(<input id="title" name="title" size="75" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_with_ac_parameters
    actual = text_field_tag "title", ActionController::Parameters.new(key: "value")
    value = CGI.escapeHTML({ "key" => "value" }.inspect)
    expected = %(<input id="title" name="title" type="text" value="#{value}" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_size_string
    actual = text_field_tag "title", "Hello!", "size" => "75"
    expected = %(<input id="title" name="title" size="75" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_maxlength_symbol
    actual = text_field_tag "title", "Hello!", maxlength: 75
    expected = %(<input id="title" name="title" maxlength="75" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_maxlength_string
    actual = text_field_tag "title", "Hello!", "maxlength" => "75"
    expected = %(<input id="title" name="title" maxlength="75" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_disabled
    actual = text_field_tag "title", "Hello!", disabled: true
    expected = %(<input id="title" name="title" disabled="disabled" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_with_placeholder_option
    actual = text_field_tag "title", "Hello!", placeholder: "Enter search term..."
    expected = %(<input id="title" name="title" placeholder="Enter search term..." type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_with_multiple_options
    actual = text_field_tag "title", "Hello!", size: 70, maxlength: 80
    expected = %(<input id="title" name="title" size="70" maxlength="80" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_text_field_tag_id_sanitized
    input_elem = root_elem(text_field_tag("item[][title]"))
    assert_match VALID_HTML_ID, input_elem["id"]
  end

  def test_label_tag_without_text
    actual = label_tag "title"
    expected = %(<label for="title">Title</label>)
    assert_dom_equal expected, actual
  end

  def test_label_tag_with_symbol
    actual = label_tag :title
    expected = %(<label for="title">Title</label>)
    assert_dom_equal expected, actual
  end

  def test_label_tag_with_text
    actual = label_tag "title", "My Title"
    expected = %(<label for="title">My Title</label>)
    assert_dom_equal expected, actual
  end

  def test_label_tag_class_string
    actual = label_tag "title", "My Title", "class" => "small_label"
    expected = %(<label for="title" class="small_label">My Title</label>)
    assert_dom_equal expected, actual
  end

  def test_label_tag_id_sanitized
    label_elem = root_elem(label_tag("item[title]"))
    assert_match VALID_HTML_ID, label_elem["for"]
  end

  def test_label_tag_with_block
    assert_dom_equal("<label>Blocked</label>", label_tag { "Blocked" })
  end

  def test_label_tag_with_block_and_argument
    output = label_tag("clock") { "Grandfather" }
    assert_dom_equal('<label for="clock">Grandfather</label>', output)
  end

  def test_label_tag_with_block_and_argument_and_options
    output = label_tag("clock", id: "label_clock") { "Grandfather" }
    assert_dom_equal('<label for="clock" id="label_clock">Grandfather</label>', output)
  end

  def test_boolean_options
    assert_dom_equal %(<input checked="checked" disabled="disabled" id="admin" name="admin" readonly="readonly" type="checkbox" value="1" />), checkbox_tag("admin", 1, true, "disabled" => true, :readonly => "yes")
    assert_dom_equal %(<input checked="checked" id="admin" name="admin" type="checkbox" value="1" />), checkbox_tag("admin", 1, true, disabled: false, readonly: nil)
    assert_dom_equal %(<input type="checkbox" />), tag(:input, type: "checkbox", checked: false)
    assert_dom_equal %(<select id="people" multiple="multiple" name="people[]"><option>david</option></select>), select_tag("people", raw("<option>david</option>"), multiple: true)
    assert_dom_equal %(<select id="people_" multiple="multiple" name="people[]"><option>david</option></select>), select_tag("people[]", raw("<option>david</option>"), multiple: true)
    assert_dom_equal %(<select id="people" name="people"><option>david</option></select>), select_tag("people", raw("<option>david</option>"), multiple: nil)
  end

  def test_stringify_symbol_keys
    actual = text_field_tag "title", "Hello!", id: "admin"
    expected = %(<input id="admin" name="title" type="text" value="Hello!" />)
    assert_dom_equal expected, actual
  end

  def test_submit_tag
    assert_dom_equal(
      %(<input name='commit' data-disable-with="Saving..." onclick="alert(&#39;hello!&#39;)" type="submit" value="Save" />),
      submit_tag("Save", onclick: "alert('hello!')", data: { disable_with: "Saving..." })
    )
  end

  def test_empty_submit_tag
    assert_dom_equal(
      %(<input data-disable-with="Save" name='commit' type="submit" value="Save" />),
      submit_tag("Save")
    )
  end

  def test_empty_submit_tag_with_opt_out
    ActionView::Base.automatically_disable_submit_tag = false
    assert_dom_equal(
      %(<input name='commit' type="submit" value="Save" />),
      submit_tag("Save")
    )
  ensure
    ActionView::Base.automatically_disable_submit_tag = true
  end

  def test_empty_submit_tag_with_opt_out_and_explicit_disabling
    ActionView::Base.automatically_disable_submit_tag = false
    assert_dom_equal(
      %(<input name='commit' type="submit" value="Save" />),
      submit_tag("Save", data: { disable_with: false })
    )
  ensure
    ActionView::Base.automatically_disable_submit_tag = true
  end

  def test_submit_tag_having_data_disable_with_string
    assert_dom_equal(
      %(<input data-disable-with="Processing..." data-confirm="Are you sure?" name='commit' type="submit" value="Save" />),
      submit_tag("Save", "data-disable-with" => "Processing...", "data-confirm" => "Are you sure?")
    )
  end

  def test_submit_tag_having_data_disable_with_boolean
    assert_dom_equal(
      %(<input data-confirm="Are you sure?" name='commit' type="submit" value="Save" />),
      submit_tag("Save", "data-disable-with" => false, "data-confirm" => "Are you sure?")
    )
  end

  def test_submit_tag_having_data_hash_disable_with_boolean
    assert_dom_equal(
      %(<input data-confirm="Are you sure?" name='commit' type="submit" value="Save" />),
      submit_tag("Save", data: { confirm: "Are you sure?", disable_with: false })
    )
  end

  def test_submit_tag_with_no_onclick_options
    assert_dom_equal(
      %(<input name='commit' data-disable-with="Saving..." type="submit" value="Save" />),
      submit_tag("Save", data: { disable_with: "Saving..." })
    )
  end

  def test_submit_tag_with_confirmation
    assert_dom_equal(
      %(<input name='commit' type='submit' value='Save' data-confirm="Are you sure?" data-disable-with="Save" />),
      submit_tag("Save", data: { confirm: "Are you sure?" })
    )
  end

  def test_submit_tag_doesnt_have_data_disable_with_twice
    assert_equal(
      %(<input type="submit" name="commit" value="Save" data-confirm="Are you sure?" data-disable-with="Processing..." />),
      submit_tag("Save", "data-disable-with" => "Processing...", "data-confirm" => "Are you sure?")
    )
  end

  def test_submit_tag_doesnt_have_data_disable_with_twice_with_hash
    assert_equal(
      %(<input type="submit" name="commit" value="Save" data-disable-with="Processing..." />),
      submit_tag("Save", data: { disable_with: "Processing..." })
    )
  end

  def test_submit_tag_with_symbol_value
    assert_dom_equal(
      %(<input data-disable-with="Save" name='commit' type="submit" value="Save" />),
      submit_tag(:Save)
    )
  end

  def test_button_tag
    assert_dom_equal(
      %(<button name="button" type="submit">Button</button>),
      button_tag
    )
  end

  def test_button_tag_with_submit_type
    assert_dom_equal(
      %(<button name="button" type="submit">Save</button>),
      button_tag("Save", type: "submit")
    )
  end

  def test_button_tag_with_button_type
    assert_dom_equal(
      %(<button name="button" type="button">Button</button>),
      button_tag("Button", type: "button")
    )
  end

  def test_button_tag_with_reset_type
    assert_dom_equal(
      %(<button name="button" type="reset">Reset</button>),
      button_tag("Reset", type: "reset")
    )
  end

  def test_button_tag_with_disabled_option
    assert_dom_equal(
      %(<button name="button" type="reset" disabled="disabled">Reset</button>),
      button_tag("Reset", type: "reset", disabled: true)
    )
  end

  def test_button_tag_escape_content
    assert_dom_equal(
      %(<button name="button" type="reset" disabled="disabled">&lt;b&gt;Reset&lt;/b&gt;</button>),
      button_tag("<b>Reset</b>", type: "reset", disabled: true)
    )
  end

  def test_button_tag_with_block
    assert_dom_equal('<button name="button" type="submit">Content</button>', button_tag { "Content" })
  end

  def test_button_tag_with_block_and_options
    output = button_tag(name: "temptation", type: "button") { content_tag(:strong, "Do not press me") }
    assert_dom_equal('<button name="temptation" type="button"><strong>Do not press me</strong></button>', output)
  end

  def test_button_tag_defaults_with_block_and_options
    output = button_tag(name: "temptation", value: "within") { content_tag(:strong, "Do not press me") }
    assert_dom_equal('<button name="temptation" value="within" type="submit" ><strong>Do not press me</strong></button>', output)
  end

  def test_button_tag_with_confirmation
    assert_dom_equal(
      %(<button name="button" type="submit" data-confirm="Are you sure?">Save</button>),
      button_tag("Save", type: "submit", data: { confirm: "Are you sure?" })
    )
  end

  def test_button_tag_with_data_disable_with_option
    assert_dom_equal(
      %(<button name="button" type="submit" data-disable-with="Please wait...">Checkout</button>),
      button_tag("Checkout", data: { disable_with: "Please wait..." })
    )
  end

  def test_image_submit_tag_with_confirmation
    assert_dom_equal(
      %(<input type="image" src="/images/save.gif" data-confirm="Are you sure?" />),
      image_submit_tag("save.gif", data: { confirm: "Are you sure?" })
    )
  end

  def test_color_field_tag
    expected = %{<input id="car" name="car" type="color" />}
    assert_dom_equal(expected, color_field_tag("car"))
  end

  def test_search_field_tag
    expected = %{<input id="query" name="query" type="search" />}
    assert_dom_equal(expected, search_field_tag("query"))
  end

  def test_telephone_field_tag
    expected = %{<input id="cell" name="cell" type="tel" />}
    assert_dom_equal(expected, telephone_field_tag("cell"))
  end

  def test_date_field_tag
    expected = %{<input id="cell" name="cell" type="date" />}
    assert_dom_equal(expected, date_field_tag("cell"))
  end

  def test_time_field_tag
    expected = %{<input id="cell" name="cell" type="time" />}
    assert_dom_equal(expected, time_field_tag("cell"))
  end

  def test_datetime_field_tag
    expected = %{<input id="appointment" name="appointment" type="datetime-local" />}
    assert_dom_equal(expected, datetime_field_tag("appointment"))
  end

  def test_datetime_local_field_tag
    expected = %{<input id="appointment" name="appointment" type="datetime-local" />}
    assert_dom_equal(expected, datetime_local_field_tag("appointment"))
  end

  def test_month_field_tag
    expected = %{<input id="birthday" name="birthday" type="month" />}
    assert_dom_equal(expected, month_field_tag("birthday"))
  end

  def test_week_field_tag
    expected = %{<input id="birthday" name="birthday" type="week" />}
    assert_dom_equal(expected, week_field_tag("birthday"))
  end

  def test_url_field_tag
    expected = %{<input id="homepage" name="homepage" type="url" />}
    assert_dom_equal(expected, url_field_tag("homepage"))
  end

  def test_email_field_tag
    expected = %{<input id="address" name="address" type="email" />}
    assert_dom_equal(expected, email_field_tag("address"))
  end

  def test_number_field_tag
    expected = %{<input name="quantity" max="9" id="quantity" type="number" min="1" />}
    assert_dom_equal(expected, number_field_tag("quantity", nil, in: 1...10))
  end

  def test_range_input_tag
    expected = %{<input name="volume" step="0.1" max="11" id="volume" type="range" min="0" />}
    assert_dom_equal(expected, range_field_tag("volume", nil, in: 0..11, step: 0.1))
  end

  def test_field_set_tag_in_erb
    output_buffer = render_erb("<%= field_set_tag('Your details') do %>Hello world!<% end %>")

    expected = %(<fieldset><legend>Your details</legend>Hello world!</fieldset>)
    assert_dom_equal expected, output_buffer

    output_buffer = render_erb("<%= field_set_tag do %>Hello world!<% end %>")

    expected = %(<fieldset>Hello world!</fieldset>)
    assert_dom_equal expected, output_buffer

    output_buffer = render_erb("<%= field_set_tag('') do %>Hello world!<% end %>")

    expected = %(<fieldset>Hello world!</fieldset>)
    assert_dom_equal expected, output_buffer

    output_buffer = render_erb("<%= field_set_tag('', :class => 'format') do %>Hello world!<% end %>")

    expected = %(<fieldset class="format">Hello world!</fieldset>)
    assert_dom_equal expected, output_buffer

    output_buffer = render_erb("<%= fieldset_tag('', :class => 'format') do %>Hello world!<% end %>")

    expected = %(<fieldset class="format">Hello world!</fieldset>)
    assert_dom_equal expected, output_buffer

    output_buffer = render_erb("<%= field_set_tag %>")

    expected = %(<fieldset></fieldset>)
    assert_dom_equal expected, output_buffer

    output_buffer = render_erb("<%= field_set_tag('You legend!') %>")

    expected = %(<fieldset><legend>You legend!</legend></fieldset>)
    assert_dom_equal expected, output_buffer
  end

  def test_textarea_tag_options_symbolize_keys_side_effects
    options = { option: "random_option" }
    textarea_tag "body", "hello world", options
    assert_equal({ option: "random_option" }, options)
  end

  def test_submit_tag_options_symbolize_keys_side_effects
    options = { option: "random_option" }
    submit_tag "submit value", options
    assert_equal({ option: "random_option" }, options)
  end

  def test_button_tag_options_symbolize_keys_side_effects
    options = { option: "random_option" }
    button_tag "button value", options
    assert_equal({ option: "random_option" }, options)
  end

  def test_image_submit_tag_options_symbolize_keys_side_effects
    options = { option: "random_option" }
    image_submit_tag "submit source", options
    assert_equal({ option: "random_option" }, options)
  end

  def test_image_label_tag_options_symbolize_keys_side_effects
    options = { option: "random_option" }
    label_tag "submit source", "title", options
    assert_equal({ option: "random_option" }, options)
  end

  def test_content_exfiltration_prevention
    with_prepend_content_exfiltration_prevention(true) do
      actual = form_tag
      expected = %(<!-- '"` --><!-- </textarea></xmp> --></option></form>#{whole_form})
      assert_dom_equal expected, actual
    end
  end

  def test_form_with_content_exfiltration_prevention_is_html_safe
    with_prepend_content_exfiltration_prevention(true) do
      assert_equal true, form_tag.html_safe?
    end
  end

  def protect_against_forgery?
    false
  end

  private
    def root_elem(rendered_content)
      Rails::Dom::Testing.html_document_fragment.parse(rendered_content).children.first # extract from nodeset
    end

    def with_default_enforce_utf8(value)
      old_value = ActionView::Helpers::FormTagHelper.default_enforce_utf8
      ActionView::Helpers::FormTagHelper.default_enforce_utf8 = value

      yield
    ensure
      ActionView::Helpers::FormTagHelper.default_enforce_utf8 = old_value
    end

    def with_prepend_content_exfiltration_prevention(value)
      old_value = ActionView::Helpers::ContentExfiltrationPreventionHelper.prepend_content_exfiltration_prevention
      ActionView::Helpers::ContentExfiltrationPreventionHelper.prepend_content_exfiltration_prevention = value

      yield
    ensure
      ActionView::Helpers::ContentExfiltrationPreventionHelper.prepend_content_exfiltration_prevention = old_value
    end
end
