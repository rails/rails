class ApplicationController < ActionController::Base
  before_action :set_active_text_renderer

  private
    def set_active_text_renderer
      ActiveText.renderer = self.class.renderer.new(request.env)
    end
end
