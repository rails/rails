# frozen_string_literal: true

Rails.application.routes.draw do
  mount <%= camelized_modules %>::Engine => "/<%= name %>"
end
