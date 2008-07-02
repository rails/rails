I18n.backend.store_translations :'en-US', {
  :support => {
    :array => {
      :sentence_connector => 'and'
    }
  },
  :date => {
    :formats => {
      :default => "%Y-%m-%d",
      :short => "%b %d",
      :long => "%B %d, %Y",
    },
    :day_names => Date::DAYNAMES,
    :abbr_day_names => Date::ABBR_DAYNAMES,
    :month_names => Date::MONTHNAMES,
    :abbr_month_names => Date::ABBR_MONTHNAMES,
    :order => [:year, :month, :day]
  },
  :time => {
    :formats => {
      :default => "%a, %d %b %Y %H:%M:%S %z",
      :short => "%d %b %H:%M",
      :long => "%B %d, %Y %H:%M",
    },
    :am => 'am',
    :pm => 'pm'
  }
}