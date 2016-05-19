require 'fileutils'

class File
  # This method allows you to determine the line endings used by a file,
  # by reading characters from the file until a known sequence of line ending 
  # characters are encountered, without reading the entire file into memory.
  # If no determination can be made, the default line ending character for 
  # the local OS is returned.
  #
  # There are 3 types of line endings: Windows (\r\n), Unix (\n), and Mac OS 9(\r)
  # By keeping an array of the 3 most recent characters, we can determine which
  # line endings are being used.
  #
  # Windows = [ any char except "\\", "\r", "\n" ]
  # Unix = [ any char, any char except "\\", "\n" ]
  # Mac OS 9 = [ any char except "\\", "\r", any char except "\n" ]
  #
  # Example:
  #
  #    line_ending_char = File.detect_line_ending_type(file_path)
  #    IO.foreach(file_path, line_ending_char, universal_newline: true) do |file_line|
  #        puts file_line
  #    end
  #
  def self.detect_line_ending_type(path)
    File.open(path, "r") do |target_file| 
      recent_chars = [nil, nil, nil]
      target_file.each_char do |char|
        recent_chars.shift
        recent_chars << char
        if recent_chars.first != "\\" && recent_chars.second == "\r" && recent_chars.third == "\n"
          return "\r\n"
        elsif recent_chars.second != "\\" && recent_chars.third == "\n"
          return "\n"
        elsif recent_chars.first != "\\" && recent_chars.second == "\r"
          return "\r"
        end
      end
    end
    return $/ # return default ruby line ending if none found in file
  end
end
