# frozen_string_literal: true

require "rails/application_controller"

class Rails::WelcomeController < Rails::ApplicationController # :nodoc:
  layout false

  def index
  end
end
