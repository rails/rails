module SystemTesting
  module TestHelpers
    module Assertions
      def assert_all_of_selectors(*items)
        options = items.extract_options!
        type = type_for_selector(items)

        items.each do |item|
          assert_selector type, item, options
        end
      end

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
