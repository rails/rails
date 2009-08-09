$:.push "rails/activesupport/lib"
$:.push "rails/actionpack/lib"

require "action_controller"

class Kaigi < ActionController::Metal
  include AbstractController::Callbacks
  include ActionController::RackConvenience
  include ActionController::RenderingController
  include ActionController::Layouts
  include ActionView::Context
  
  before_filter :set_name
  append_view_path "views"
  
  def view_context
    self
  end
  
  def controller
    self
  end

  DEFAULT_LAYOUT = Object.new.tap {|l| def l.render(*) yield end }
  
  def render_template(template, layout = DEFAULT_LAYOUT, options = {}, partial = false)
    ret = template.render(self, {})
    layout.render(self, {}) { ret }
  end
  
  def index
    render :template => "template"
  end
  
  def alt
    render :template => "template", :layout => "alt"
  end
  
  private
  def set_name
    @name = params[:name]
  end
end

app = Rack::Builder.new do
  map("/kaigi") {  run Kaigi.action(:index) }
  map("/kaigi/alt") { run Kaigi.action(:alt) }
end.to_app

Rack::Handler::Mongrel.run app, :Port => 3000
