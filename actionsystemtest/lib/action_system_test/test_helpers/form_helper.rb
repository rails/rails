module ActionSystemTest
  module TestHelpers
    # Form helpers for system testing that aren't included by default in
    # Capybara.
    module FormHelper
      # Finds all provided fields or text areas and fills in with supplied values.
      #
      #   fill_in_all_fields('Name' => 'Eileen', 'Job Title' => 'Programmer')
      def fill_in_all_fields(fields)
        fields.each do |name, value|
          fill_in name, with: value
        end
      end

      # Locates a checkbox that is present inside a label and checks it. When
      # using styled boxes Selenium may not be able to see the checkbox. This
      # form helper looks inside the checkbox and clicks the label instead of
      # setting the value of the checkbox.
      #
      #   click_checkbox_label 'Admin'
      #
      # By default +click_checkbox_label+ looks for checkboxes that are not
      # checked by default. To locate an already checked box and uncheck it
      # set checked to true:
      #
      #   click_checkbox_label 'Admin', checked: true
      def click_checkbox_label(name, checked: false)
        field = find_checkbox(name, checked)
        label = find_label_wrapper(field)
        label.click
      end

      # In lieu of locating a button and calling +click_on+, +press_enter+ will
      # submit the form via enter. This method will only work for drivers that
      # load a browser like Selenium.
      #
      #   test 'Adding a User' do
      #     fill_in 'Name', with: 'Arya'
      #
      #     press_enter
      #
      #     assert_text 'Arya'
      #   end
      def press_enter
        page.driver.browser.action.send_keys(:enter).perform
      end

      private
        def find_checkbox(name, checked)
          find(:field, name, visible: :all, checked: checked)
        end

        def find_label_wrapper(field, location: "./ancestor::label")
          field.find :xpath, location
        end
    end
  end
end
