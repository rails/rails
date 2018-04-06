# frozen_string_literal: true

# The base controller for all ActiveStorage controllers.
class ActiveStorage::BaseController < ActionController::Base
  protect_from_forgery with: :exception
end
