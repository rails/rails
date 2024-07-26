# The methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def self.append_features(controller) #:nodoc:
    controller.ancestors.include?(ActionController::Base) ? controller.add_template_helper(self) : super
  end
end
