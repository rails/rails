# frozen_string_literal: true

{
  en: {
    number: {
      nth: {
        ordinals: lambda do |_key, number:, **_options|
          abs_number = number.to_i.abs

          if (11..13).cover?(abs_number % 100)
            "th"
          else
            case abs_number % 10
            when 1 then "st"
            when 2 then "nd"
            when 3 then "rd"
            else "th"
            end
          end
        end,

        ordinalized: lambda do |_key, number:, **_options|
          "#{number}#{ActiveSupport::Inflector.ordinal(number)}"
        end
      }
    }
  }
}
