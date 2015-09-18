# Entry-object implementation for reduced serialization overhead.
class ASCE_5 < ActiveSupport::Cache::Entry
  MAX_OVERHEAD = 16
  MIN_OVERHEAD = 12

  def _dump(levels)
    expires_at = @expires_in ? [@created_at.to_f + @expires_in].pack('L') : ''.b
    expires_at << Marshal.dump(@value, levels)
  end

  def self._load(str)
    self.allocate.send(:marshal_load, str)
  end

  private
  MARSHAL_HEADER = [Marshal::MAJOR_VERSION, Marshal::MINOR_VERSION]
  ZLIB_HEADER = [120, 156]

  def marshal_load(str)
    # Detect Marshal object based on header bytes
    has_expires_at = str[0..1].unpack('C*') != MARSHAL_HEADER
    if has_expires_at
      expires_at = str.slice!(0,4).unpack('L').first
      @created_at = [Time.now.to_f, expires_at - 1].min
      @expires_in = expires_at - @created_at
    else
      @created_at = Time.now.to_f
      @expires_in = nil
    end
    @value = Marshal.load(str)
    @s = str.bytesize
    # Detect Zlib-compressed value based on header bytes
    @compressed = true if @value.is_a?(String) && @value[0..1].unpack('C*') == ZLIB_HEADER
    self
  end
end
