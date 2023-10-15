# frozen_string_literal: true

require "rails/testing/capybara_extensions"

Capybara::Selector.all.each_key do |selector_name|
  Rails::Testing::CapybaraExtensions.install(selector_name)
end
