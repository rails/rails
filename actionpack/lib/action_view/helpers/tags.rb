module ActionView
  module Helpers
    module Tags #:nodoc:
      extend ActiveSupport::Autoload

      autoload :Base
      autoload :Label
      autoload :TextField
      autoload :PasswordField
      autoload :HiddenField
      autoload :FileField
      autoload :SearchField
      autoload :TelField
      autoload :UrlField
      autoload :EmailField
      autoload :NumberField
      autoload :RangeField
      autoload :TextArea
      autoload :CheckBox
      autoload :RadioButton
      autoload :Select
      autoload :CollectionSelect
      autoload :GroupedCollectionSelect
      autoload :TimeZoneSelect
      autoload :DateSelect
      autoload :TimeSelect
      autoload :DatetimeSelect
    end
  end
end
