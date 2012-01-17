module ActionView
  module Helpers
    module Tags
      autoload :Base,                    'action_view/helpers/tags/base'
      autoload :Label,                   'action_view/helpers/tags/label'
      autoload :TextField,               'action_view/helpers/tags/text_field'
      autoload :PasswordField,           'action_view/helpers/tags/password_field'
      autoload :HiddenField,             'action_view/helpers/tags/hidden_field'
      autoload :FileField,               'action_view/helpers/tags/file_field'
      autoload :SearchField,             'action_view/helpers/tags/search_field'
      autoload :TelField,                'action_view/helpers/tags/tel_field'
      autoload :UrlField,                'action_view/helpers/tags/url_field'
      autoload :EmailField,              'action_view/helpers/tags/email_field'
      autoload :NumberField,             'action_view/helpers/tags/number_field'
      autoload :RangeField,              'action_view/helpers/tags/range_field'
      autoload :TextArea,                'action_view/helpers/tags/text_area'
      autoload :CheckBox,                'action_view/helpers/tags/check_box'
      autoload :RadioButton,             'action_view/helpers/tags/radio_button'
      autoload :Select,                  'action_view/helpers/tags/select'
      autoload :CollectionSelect,        'action_view/helpers/tags/collection_select'
      autoload :GroupedCollectionSelect, 'action_view/helpers/tags/grouped_collection_select'
      autoload :TimeZoneSelect,          'action_view/helpers/tags/time_zone_select'
      autoload :DateSelect,              'action_view/helpers/tags/date_select'
      autoload :TimeSelect,              'action_view/helpers/tags/time_select'
      autoload :DatetimeSelect,          'action_view/helpers/tags/datetime_select'
    end
  end
end
