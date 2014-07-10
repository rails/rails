module ActiveRecord
  module Type
    module TimeValue # :nodoc:
      def klass
        ::Time
      end

      def type_cast_for_schema(value)
        "'#{value.to_s(:db)}'"
      end

      private

      def new_time(year, mon, mday, hour, min, sec, microsec, offset = nil)
        # Treat 0000-00-00 00:00:00 as nil.
        return if year.nil? || (year == 0 && mon == 0 && mday == 0)

        if offset
          time = ::Time.utc(year, mon, mday, hour, min, sec, microsec) rescue nil
          return unless time

          time -= offset
          Base.default_timezone == :utc ? time : time.getlocal
        else
          ::Time.public_send(Base.default_timezone, year, mon, mday, hour, min, sec, microsec) rescue nil
        end
      end

      # Doesn't handle time zones.
      def fast_string_to_time(string)
        if string =~ ConnectionAdapters::Column::Format::ISO_DATETIME
          microsec = ($7.to_r * 1_000_000).to_i
          new_time $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, microsec
        end
      end
    end
  end
end
