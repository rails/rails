# frozen_string_literal: true

require_relative "application_controller"

class Rails::WelcomeController < Rails::ApplicationController # :nodoc:
  layout false

  def index
  end
end
