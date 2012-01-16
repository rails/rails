module ActionView
  module Helpers
    module Tags
      autoload :Base,          'action_view/helpers/tags/base'
      autoload :Label,         'action_view/helpers/tags/label'
      autoload :TextField,     'action_view/helpers/tags/text_field'
      autoload :PasswordField, 'action_view/helpers/tags/password_field'
    end
  end
end
