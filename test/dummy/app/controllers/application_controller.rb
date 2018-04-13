class ApplicationController < ActionController::Base
  before_action :set_action_text_renderer

  private
    def set_action_text_renderer
      ActionText.renderer = self.class.renderer.new(request.env)
    end
end
