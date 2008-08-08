I18n.backend.store_translations :'en-US', {
  :datetime => {
    :distance_in_words => {
      :half_a_minute       => 'half a minute',
      :less_than_x_seconds => ['less than 1 second', 'less than {{count}} seconds'],
      :x_seconds           => ['1 second', '{{count}} seconds'],
      :less_than_x_minutes => ['less than a minute', 'less than {{count}} minutes'],
      :x_minutes           => ['1 minute', '{{count}} minutes'],
      :about_x_hours       => ['about 1 hour', 'about {{count}} hours'],
      :x_days              => ['1 day', '{{count}} days'],
      :about_x_months      => ['about 1 month', 'about {{count}} months'],
      :x_months            => ['1 month', '{{count}} months'],
      :about_x_years       => ['about 1 year', 'about {{count}} year'],
      :over_x_years        => ['over 1 year', 'over {{count}} years']
    }
  },
  :number => {
    :format => {
      :precision => 3,
      :separator => '.',
      :delimiter => ','
    },
    :currency => {
      :format => {
        :unit => '$',
        :precision => 2,
        :format => '%u%n'
      }
    },
    :human => {
      :format => {
        :precision => 1,
        :delimiter => ''
      }
    },
    :percentage => {
      :format => {
        :delimiter => ''
      }
    },
    :precision => {
      :format => {
        :delimiter => ''
      }
    }
  },
  :active_record => {
    :error => {
      :header_message => ["1 error prohibited this {{object_name}} from being saved", "{{count}} errors prohibited this {{object_name}} from being saved"],
      :message => "There were problems with the following fields:"
    }
  }
}
