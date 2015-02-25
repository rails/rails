# Parses a string formatted according to ISO 8601 Duration into the hash .
#
# See http://en.wikipedia.org/wiki/ISO_8601#Durations
# Parts of code are taken from ISO8601 gem by Arnau Siches (@arnau).
# This parser isn't so strict and allows negative parts to be present in pattern.
class ActiveSupport::Duration::ISO8601DurationParser
  attr_reader :parts

  class ParsingError < ::StandardError; end

  def initialize(iso8601duration)
    @raw = iso8601duration
    parse_iso_duration!
    construct_parts
    validate_parts!
  end

  private

  def parse_iso_duration!
    @match = @raw.match(/^
                (?<sign>\+|-)?
                P(?:
                  (?:
                    (?:(?<years>-?\d+(?:[,.]\d+)?)Y)?
                    (?:(?<months>-?\d+(?:[.,]\d+)?)M)?
                    (?:(?<days>-?\d+(?:[.,]\d+)?)D)?
                    (?<time>T
                      (?:(?<hours>-?\d+(?:[.,]\d+)?)H)?
                      (?:(?<minutes>-?\d+(?:[.,]\d+)?)M)?
                      (?:(?<seconds>-?\d+(?:[.,]\d+)?)S)?
                    )?
                  ) |
                  (?<weeks>-?\d+(?:[.,]\d+)?W)
                ) # Duration
              $/x) || raise(ParsingError.new("Invalid ISO 8601 duration: #{@raw}"))
  end

  # Constructs parts compatible with +ActiveSupport::Duration+ ones.
  def construct_parts
    sign = @match[:sign] == '-' ? -1 : 1
    @parts = @match.names.zip(@match.captures).reject { |_k,v| v.nil? }.map do |k, v|
      value = /\d+[\.,]\d+/ =~ v ? v.sub(',', '.').to_f : v.to_i
      [ k.to_sym, sign * value ]
    end
    @parts = ::Hash[@parts].slice(:years, :months, :weeks, :days, :hours, :minutes, :seconds)
  end

  # Checks for various semantic errors as stated in ISO 8601 standard
  def validate_parts!
    # Validate that is not empty duration or time part is not empty if 'T' marker present
    if @parts.empty? || (@match[:time].present? && @match[:time][1..-1].empty?)
      raise ParsingError.new("Invalid ISO 8601 duration: #{@raw} (empty duration or empty time part)")
    end
    # Validate fractions (standard allows only last part to be fractional)
    fractions = @parts.values.reject(&:zero?).select { |a| (a % 1) != 0 }
    unless fractions.empty? || (fractions.size == 1 && fractions.last == @parts.values.reject(&:zero?).last)
      raise ParsingError.new("Invalid ISO 8601 duration: #{@raw} (only last part can be fractional)")
    end
  end
end
