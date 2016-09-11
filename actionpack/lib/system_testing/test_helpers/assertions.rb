module SystemTesting
  module TestHelpers
    # Assertions for system testing that aren't included by default in Capybara.
    # These are assertions that are useful specifically for Rails applications.
    module Assertions
      # Asserts that all of the provided selectors are present on the given page.
      #
      #   assert_all_of_selectors('p', 'td')
      def assert_all_of_selectors(*items)
        options = items.extract_options!
        type = type_for_selector(items)

        items.each do |item|
          assert_selector type, item, options
        end
      end

      # Asserts that none of the provided selectors are present on the page.
      #
      #   assert_none_of_selectors('ul', 'ol')
      def assert_none_of_selectors(*items)
        options = items.extract_options!
        type = type_for_selector(items)

        items.each do |item|
          assert_no_selector type, item, options
        end
      end

      private
        def type_for_selector(*items)
          if items.first.is_a?(Symbol)
            items.shift
          else
            Capybara.default_selector
          end
        end
    end
  end
end
