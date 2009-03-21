class Numeric
  UTC_OFFSET_WITH_COLON = '%+03d:%02d'
  UTC_OFFSET_WITHOUT_COLON = UTC_OFFSET_WITH_COLON.sub(':', '')

  # Assumes self represents an offset from UTC in seconds (as returned from Time#utc_offset)
  # and turns this into an +HH:MM formatted string. Example:
  #
  #   -21_600.to_utc_offset_s   # => "-06:00"
  def to_utc_offset_s(colon = true)
    format = colon ? UTC_OFFSET_WITH_COLON : UTC_OFFSET_WITHOUT_COLON
    hours = self / 3600
    minutes = (abs % 3600) / 60
    format % [hours, minutes]
  end
end
