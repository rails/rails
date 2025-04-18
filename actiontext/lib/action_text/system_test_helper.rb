# frozen_string_literal: true

# :markup: markdown

module ActionText
  module SystemTestHelper
    # Locates a Trix editor and fills it in with the given HTML.
    #
    # The editor can be found by:
    #
    # *   its `id`
    # *   its `placeholder`
    # *   the text from its `label` element
    # *   its `aria-label`
    # *   the `name` of its input
    #
    #
    # Examples:
    #
    #     # <trix-editor id="message_content" ...></trix-editor>
    #     fill_in_rich_textarea "message_content", with: "Hello <em>world!</em>"
    #
    #     # <trix-editor placeholder="Your message here" ...></trix-editor>
    #     fill_in_rich_textarea "Your message here", with: "Hello <em>world!</em>"
    #
    #     # <label for="message_content">Message content</label>
    #     # <trix-editor id="message_content" ...></trix-editor>
    #     fill_in_rich_textarea "Message content", with: "Hello <em>world!</em>"
    #
    #     # <trix-editor aria-label="Message content" ...></trix-editor>
    #     fill_in_rich_textarea "Message content", with: "Hello <em>world!</em>"
    #
    #     # <input id="trix_input_1" name="message[content]" type="hidden">
    #     # <trix-editor input="trix_input_1"></trix-editor>
    #     fill_in_rich_textarea "message[content]", with: "Hello <em>world!</em>"
    def fill_in_rich_textarea(locator = nil, with:)
      find(:rich_textarea, locator).execute_script("this.editor.loadHTML(arguments[0])", with.to_s)
    end
    alias_method :fill_in_rich_text_area, :fill_in_rich_textarea
  end
end

%i[rich_textarea rich_text_area].each do |rich_textarea|
  Capybara.add_selector rich_textarea do
    label "rich-text area"
    xpath do |locator|
      if locator.nil?
        XPath.descendant(:"trix-editor")
      else
        input_located_by_name = XPath.anywhere(:input).where(XPath.attr(:name) == locator).attr(:id)
        input_located_by_label = XPath.anywhere(:label).where(XPath.string.n.is(locator)).attr(:for)

        XPath.descendant(:"trix-editor").where \
          XPath.attr(:id).equals(locator) |
          XPath.attr(:placeholder).equals(locator) |
          XPath.attr(:"aria-label").equals(locator) |
          XPath.attr(:input).equals(input_located_by_name) |
          XPath.attr(:id).equals(input_located_by_label)
      end
    end
  end
end
