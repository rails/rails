require 'abstract_unit'

class Category < Struct.new(:id, :name)
end

class FormCollectionsHelperTest < ActionView::TestCase
  def assert_no_select(selector, value = nil)
    assert_select(selector, :text => value, :count => 0)
  end

  def with_collection_radio_buttons(*args, &block)
    concat collection_radio_buttons(*args, &block)
  end

  def with_collection_check_boxes(*args, &block)
    concat collection_check_boxes(*args, &block)
  end

  # COLLECTION RADIO BUTTONS
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

  # COLLECTION CHECK BOXES
  test 'collection check boxes accepts a collection and generate a serie of checkboxes for value method' do
    collection = [Category.new(1, 'Category 1'), Category.new(2, 'Category 2')]
    with_collection_check_boxes :user, :category_ids, collection, :id, :name

    assert_select 'input#user_category_ids_1[type=checkbox][value=1]'
    assert_select 'input#user_category_ids_2[type=checkbox][value=2]'
  end

  test 'collection check boxes generates only one hidden field for the entire collection, to ensure something will be sent back to the server when posting an empty collection' do
    collection = [Category.new(1, 'Category 1'), Category.new(2, 'Category 2')]
    with_collection_check_boxes :user, :category_ids, collection, :id, :name

    assert_select "input[type=hidden][name='user[category_ids][]'][value=]", :count => 1
  end

  test 'collection check boxes accepts a collection and generate a serie of checkboxes with labels for label method' do
    collection = [Category.new(1, 'Category 1'), Category.new(2, 'Category 2')]
    with_collection_check_boxes :user, :category_ids, collection, :id, :name

    assert_select 'label.collection_check_boxes[for=user_category_ids_1]', 'Category 1'
    assert_select 'label.collection_check_boxes[for=user_category_ids_2]', 'Category 2'
  end

  test 'collection check boxes handles camelized collection values for labels correctly' do
    with_collection_check_boxes :user, :active, ['Yes', 'No'], :to_s, :to_s

    assert_select 'label.collection_check_boxes[for=user_active_yes]', 'Yes'
    assert_select 'label.collection_check_boxes[for=user_active_no]', 'No'
  end

  test 'colection check box should sanitize collection values for labels correctly' do
    with_collection_check_boxes :user, :name, ['$0.99', '$1.99'], :to_s, :to_s
    assert_select 'label.collection_check_boxes[for=user_name_099]', '$0.99'
    assert_select 'label.collection_check_boxes[for=user_name_199]', '$1.99'
  end

  test 'collection check boxes accepts selected values as :checked option' do
    collection = (1..3).map{|i| [i, "Category #{i}"] }
    with_collection_check_boxes :user, :category_ids, collection, :first, :last, :checked => [1, 3]

    assert_select 'input[type=checkbox][value=1][checked=checked]'
    assert_select 'input[type=checkbox][value=3][checked=checked]'
    assert_no_select 'input[type=checkbox][value=2][checked=checked]'
  end

  test 'collection check boxes accepts a single checked value' do
    collection = (1..3).map{|i| [i, "Category #{i}"] }
    with_collection_check_boxes :user, :category_ids, collection, :first, :last, :checked => 3

    assert_select 'input[type=checkbox][value=3][checked=checked]'
    assert_no_select 'input[type=checkbox][value=1][checked=checked]'
    assert_no_select 'input[type=checkbox][value=2][checked=checked]'
  end

  test 'collection check boxes accepts selected values as :checked option and override the model values' do
    skip "check with fields for"
    collection = (1..3).map{|i| [i, "Category #{i}"] }
    :user.category_ids = [2]
    with_collection_check_boxes :user, :category_ids, collection, :first, :last, :checked => [1, 3]

    assert_select 'input[type=checkbox][value=1][checked=checked]'
    assert_select 'input[type=checkbox][value=3][checked=checked]'
    assert_no_select 'input[type=checkbox][value=2][checked=checked]'
  end

  test 'collection check boxes accepts multiple disabled items' do
    collection = (1..3).map{|i| [i, "Category #{i}"] }
    with_collection_check_boxes :user, :category_ids, collection, :first, :last, :disabled => [1, 3]

    assert_select 'input[type=checkbox][value=1][disabled=disabled]'
    assert_select 'input[type=checkbox][value=3][disabled=disabled]'
    assert_no_select 'input[type=checkbox][value=2][disabled=disabled]'
  end

  test 'collection check boxes accepts single disable item' do
    collection = (1..3).map{|i| [i, "Category #{i}"] }
    with_collection_check_boxes :user, :category_ids, collection, :first, :last, :disabled => 1

    assert_select 'input[type=checkbox][value=1][disabled=disabled]'
    assert_no_select 'input[type=checkbox][value=3][disabled=disabled]'
    assert_no_select 'input[type=checkbox][value=2][disabled=disabled]'
  end

  test 'collection check boxes accepts a proc to disabled items' do
    collection = (1..3).map{|i| [i, "Category #{i}"] }
    with_collection_check_boxes :user, :category_ids, collection, :first, :last, :disabled => proc { |i| i.first == 1 }

    assert_select 'input[type=checkbox][value=1][disabled=disabled]'
    assert_no_select 'input[type=checkbox][value=3][disabled=disabled]'
    assert_no_select 'input[type=checkbox][value=2][disabled=disabled]'
  end

  test 'collection check boxes accepts html options' do
    collection = [[1, 'Category 1'], [2, 'Category 2']]
    with_collection_check_boxes :user, :category_ids, collection, :first, :last, {}, :class => 'check'

    assert_select 'input.check[type=checkbox][value=1]'
    assert_select 'input.check[type=checkbox][value=2]'
  end

  test 'collection check boxes with fields for' do
    skip "test collection check boxes with fields for (and radio buttons as well)"
    collection = [Category.new(1, 'Category 1'), Category.new(2, 'Category 2')]
    concat(form_for(:user) do |f|
      f.fields_for(:post) do |p|
        p.collection_check_boxes :category_ids, collection, :id, :name
      end
    end)

    assert_select 'input#user_post_category_ids_1[type=checkbox][value=1]'
    assert_select 'input#user_post_category_ids_2[type=checkbox][value=2]'

    assert_select 'label.collection_check_boxes[for=user_post_category_ids_1]', 'Category 1'
    assert_select 'label.collection_check_boxes[for=user_post_category_ids_2]', 'Category 2'
  end

  test 'collection check boxeses wraps the collection in the given collection wrapper tag' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s, :collection_wrapper_tag => :ul

    assert_select 'ul input[type=checkbox]', :count => 2
  end

  test 'collection check boxeses does not render any wrapper tag by default' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s

    assert_select 'input[type=checkbox]', :count => 2
    assert_no_select 'ul'
  end

  test 'collection check boxeses does not wrap the collection when given falsy values' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s, :collection_wrapper_tag => false

    assert_select 'input[type=checkbox]', :count => 2
    assert_no_select 'ul'
  end

  test 'collection check boxeses uses the given class for collection wrapper tag' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s,
      :collection_wrapper_tag => :ul, :collection_wrapper_class => "items-list"

    assert_select 'ul.items-list input[type=checkbox]', :count => 2
  end

  test 'collection check boxeses uses no class for collection wrapper tag when no wrapper tag is given' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s,
      :collection_wrapper_class => "items-list"

    assert_select 'input[type=checkbox]', :count => 2
    assert_no_select 'ul'
    assert_no_select '.items-list'
  end

  test 'collection check boxeses uses no class for collection wrapper tag by default' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s, :collection_wrapper_tag => :ul

    assert_select 'ul'
    assert_no_select 'ul[class]'
  end

  test 'collection check boxeses wrap items in a span tag by default' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s

    assert_select 'span input[type=checkbox]', :count => 2
  end

  test 'collection check boxeses wraps each item in the given item wrapper tag' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s, :item_wrapper_tag => :li

    assert_select 'li input[type=checkbox]', :count => 2
  end

  test 'collection check boxeses does not wrap each item when given explicitly falsy value' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s, :item_wrapper_tag => false

    assert_select 'input[type=checkbox]'
    assert_no_select 'span input[type=checkbox]'
  end

  test 'collection check boxeses uses the given class for item wrapper tag' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s,
      :item_wrapper_tag => :li, :item_wrapper_class => "inline"

    assert_select "li.inline input[type=checkbox]", :count => 2
  end

  test 'collection check boxeses uses no class for item wrapper tag when no wrapper tag is given' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s,
      :item_wrapper_tag => nil, :item_wrapper_class => "inline"

    assert_select 'input[type=checkbox]', :count => 2
    assert_no_select 'li'
    assert_no_select '.inline'
  end

  test 'collection check boxeses uses no class for item wrapper tag by default' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s,
      :item_wrapper_tag => :li

    assert_select "li", :count => 2
    assert_no_select "li[class]"
  end

  test 'collection check boxes does not wrap input inside the label' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s

    assert_select 'input[type=checkbox] + label'
    assert_no_select 'label input'
  end

  test 'collection check boxes accepts a block to render the radio and label as required' do
    with_collection_check_boxes :user, :active, [true, false], :to_s, :to_s do |label_for, text, value, html_options|
      label(:user, label_for, text) { check_box(:user, :active, html_options, value) }
    end

    assert_select 'label[for=user_active_true] > input#user_active_true[type=checkbox]'
    assert_select 'label[for=user_active_false] > input#user_active_false[type=checkbox]'
  end
end
