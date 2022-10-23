# frozen_string_literal: true

require "rails/application_controller"

class Rails::WelcomeController < Rails::ApplicationController # :nodoc:
  skip_forgery_protection
  layout false

  def index
  end
end
