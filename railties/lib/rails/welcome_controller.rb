class Rails::WelcomeController < ActionController::Base # :nodoc:
  self.view_paths = File.expand_path('../templates', __FILE__)
  layout nil

  def index
  end
end
