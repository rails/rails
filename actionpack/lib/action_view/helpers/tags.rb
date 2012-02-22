module ActionView
  module Helpers
    module Tags #:nodoc:
      extend ActiveSupport::Autoload

      autoload :Base
      autoload :CheckBox
      autoload :CollectionCheckBoxes
      autoload :CollectionRadioButtons
      autoload :CollectionSelect
      autoload :DateField
      autoload :DateSelect
      autoload :DatetimeSelect
      autoload :EmailField
      autoload :FileField
      autoload :GroupedCollectionSelect
      autoload :HiddenField
      autoload :Label
      autoload :NumberField
      autoload :PasswordField
      autoload :RadioButton
      autoload :RangeField
      autoload :SearchField
      autoload :Select
      autoload :TelField
      autoload :TextArea
      autoload :TextField
      autoload :TimeSelect
      autoload :TimeZoneSelect
      autoload :UrlField
    end
  end
end
