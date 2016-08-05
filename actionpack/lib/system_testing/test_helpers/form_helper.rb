module SystemTesting
  module TestHelpers
    module FormHelper
      def fill_in_all_fields(fields)
        fields.each do |name, value|
          fill_in name, with: value
        end
      end

      def click_checkbox_label(name, checked: false)
        field = find_checkbox(name, checked)
        label = find_label_wrapper(field)
        label.click
      end

      def press_enter
        page.driver.browser.action.send_keys(:enter).perform
      end

      private
        def find_checkbox(name, checked)
          find(:field, name, visible: :all, checked: checked)
        end

        def find_label_wrapper(field, location: './ancestor::label')
          field.find :xpath, location
        end
    end
  end
end
