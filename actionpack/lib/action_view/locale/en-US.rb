I18n.backend.store_translations :'en-US', {
  :datetime => {
    :distance_in_words => {
      :half_a_minute => 'half a minute',
      :less_than_x_seconds => {
        :one => 'less than 1 second', 
        :many => 'less than {{count}} seconds'
      },
      :x_seconds => {
        :one => '1 second', 
        :many => '{{count}} seconds'
      },
      :less_than_x_minutes => {
        :one => 'less than a minute', 
        :many => 'less than {{count}} minutes'
      },
      :x_minutes => {
        :one => '1 minute', 
        :many => '{{count}} minutes'
      },
      :about_x_hours => {
        :one => 'about 1 hour', 
        :many => 'about {{count}} hours'
      },
      :x_days => {
        :one => '1 day',
        :many => '{{count}} days' 
      },
      :about_x_months => { 
        :one => 'about 1 month', 
        :many => 'about {{count}} months'
      },
      :x_months => {
        :one => '1 month', 
        :many => '{{count}} months'
      },
      :about_x_years => {
        :one => 'about 1 year', 
        :many => 'about {{count}} years'
      },
      :over_x_years => {
        :one => 'over 1 year', 
        :many => 'over {{count}} years'
      }
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
      :header_message => {
        :one => "1 error prohibited this {{object_name}} from being saved", 
        :many => "{{count}} errors prohibited this {{object_name}} from being saved"
      },
      :message => "There were problems with the following fields:"
    }
  }
}
