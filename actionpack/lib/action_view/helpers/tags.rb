module ActionView
  module Helpers
    module Tags
      autoload :Base,          'action_view/helpers/tags/base'
      autoload :Label,         'action_view/helpers/tags/label'
      autoload :TextField,     'action_view/helpers/tags/text_field'
      autoload :PasswordField, 'action_view/helpers/tags/password_field'
      autoload :HiddenField,   'action_view/helpers/tags/hidden_field'
      autoload :FileField,     'action_view/helpers/tags/file_field'
      autoload :TextArea,      'action_view/helpers/tags/text_area'
      autoload :CheckBox,      'action_view/helpers/tags/check_box'
      autoload :RadioButton,   'action_view/helpers/tags/radio_button'
    end
  end
end
