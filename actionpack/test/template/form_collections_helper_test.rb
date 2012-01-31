require 'abstract_unit'

class FormCollectionsHelperTest < ActionView::TestCase
  def assert_no_select(selector, value = nil)
    assert_select(selector, :text => value, :count => 0)
  end

  def with_collection_radio_buttons(*args, &block)
    concat collection_radio_buttons(*args, &block)
  end

  # COLLECTION RADIO
  test 'collection radio accepts a collection and generate inputs from value method' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s

    assert_select 'input[type=radio][value=true]#user_active_true'
    assert_select 'input[type=radio][value=false]#user_active_false'
  end

  test 'collection radio accepts a collection and generate inputs from label method' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s

    assert_select 'label.collection_radio_buttons[for=user_active_true]', 'true'
    assert_select 'label.collection_radio_buttons[for=user_active_false]', 'false'
  end

  test 'collection radio handles camelized collection values for labels correctly' do
    with_collection_radio_buttons :user, :active, ['Yes', 'No'], :to_s, :to_s

    assert_select 'label.collection_radio_buttons[for=user_active_yes]', 'Yes'
    assert_select 'label.collection_radio_buttons[for=user_active_no]', 'No'
  end

  test 'colection radio should sanitize collection values for labels correctly' do
    with_collection_radio_buttons :user, :name, ['$0.99', '$1.99'], :to_s, :to_s
    assert_select 'label.collection_radio_buttons[for=user_name_099]', '$0.99'
    assert_select 'label.collection_radio_buttons[for=user_name_199]', '$1.99'
  end

  test 'collection radio accepts checked item' do
    with_collection_radio_buttons :user, :active, [[1, true], [0, false]], :last, :first, :checked => true

    assert_select 'input[type=radio][value=true][checked=checked]'
    assert_no_select 'input[type=radio][value=false][checked=checked]'
  end

  test 'collection radio accepts multiple disabled items' do
    collection = [[1, true], [0, false], [2, 'other']]
    with_collection_radio_buttons :user, :active, collection, :last, :first, :disabled => [true, false]

    assert_select 'input[type=radio][value=true][disabled=disabled]'
    assert_select 'input[type=radio][value=false][disabled=disabled]'
    assert_no_select 'input[type=radio][value=other][disabled=disabled]'
  end

  test 'collection radio accepts single disable item' do
    collection = [[1, true], [0, false]]
    with_collection_radio_buttons :user, :active, collection, :last, :first, :disabled => true

    assert_select 'input[type=radio][value=true][disabled=disabled]'
    assert_no_select 'input[type=radio][value=false][disabled=disabled]'
  end

  test 'collection radio accepts html options as input' do
    collection = [[1, true], [0, false]]
    with_collection_radio_buttons :user, :active, collection, :last, :first, {}, :class => 'special-radio'

    assert_select 'input[type=radio][value=true].special-radio#user_active_true'
    assert_select 'input[type=radio][value=false].special-radio#user_active_false'
  end

  test 'collection radio wraps the collection in the given collection wrapper tag' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s, :collection_wrapper_tag => :ul

    assert_select 'ul input[type=radio]', :count => 2
  end

  test 'collection radio does not render any wrapper tag by default' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s

    assert_select 'input[type=radio]', :count => 2
    assert_no_select 'ul'
  end

  test 'collection radio does not wrap the collection when given falsy values' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s, :collection_wrapper_tag => false

    assert_select 'input[type=radio]', :count => 2
    assert_no_select 'ul'
  end

  test 'collection radio uses the given class for collection wrapper tag' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s,
      :collection_wrapper_tag => :ul, :collection_wrapper_class => "items-list"

    assert_select 'ul.items-list input[type=radio]', :count => 2
  end

  test 'collection radio uses no class for collection wrapper tag when no wrapper tag is given' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s,
      :collection_wrapper_class => "items-list"

    assert_select 'input[type=radio]', :count => 2
    assert_no_select 'ul'
    assert_no_select '.items-list'
  end

  test 'collection radio uses no class for collection wrapper tag by default' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s, :collection_wrapper_tag => :ul

    assert_select 'ul'
    assert_no_select 'ul[class]'
  end

  test 'collection radio wrap items in a span tag by default' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s

    assert_select 'span input[type=radio][value=true]#user_active_true + label'
    assert_select 'span input[type=radio][value=false]#user_active_false + label'
  end

  test 'collection radio wraps each item in the given item wrapper tag' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s, :item_wrapper_tag => :li

    assert_select 'li input[type=radio]', :count => 2
  end

  test 'collection radio does not wrap each item when given explicitly falsy value' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s, :item_wrapper_tag => false

    assert_select 'input[type=radio]'
    assert_no_select 'span input[type=radio]'
  end

  test 'collection radio uses the given class for item wrapper tag' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s,
      :item_wrapper_tag => :li, :item_wrapper_class => "inline"

    assert_select "li.inline input[type=radio]", :count => 2
  end

  test 'collection radio uses no class for item wrapper tag when no wrapper tag is given' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s,
      :item_wrapper_tag => nil, :item_wrapper_class => "inline"

    assert_select 'input[type=radio]', :count => 2
    assert_no_select 'li'
    assert_no_select '.inline'
  end

  test 'collection radio uses no class for item wrapper tag by default' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s,
      :item_wrapper_tag => :li

    assert_select "li", :count => 2
    assert_no_select "li[class]"
  end

  test 'collection radio does not wrap input inside the label' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s

    assert_select 'input[type=radio] + label'
    assert_no_select 'label input'
  end

  test 'collection radio accepts a block to render the radio and label as required' do
    with_collection_radio_buttons :user, :active, [true, false], :to_s, :to_s do |label_for, text, value, html_options|
      concat label(:user, label_for, text) { radio_button(:user, :active, value, html_options) }
    end

    assert_select 'label[for=user_active_true] > input#user_active_true[type=radio]'
    assert_select 'label[for=user_active_false] > input#user_active_false[type=radio]'
  end
end
