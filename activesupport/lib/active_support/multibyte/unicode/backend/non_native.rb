module ActiveSupport
  module Multibyte
    module Unicode
      module Backend
        module NonNative # :nodoc:
          # The Unicode version that is supported by the implementation
          UNICODE_VERSION = "9.0.0"

          # Hangul character boundaries and properties
          HANGUL_SBASE = 0xAC00
          HANGUL_LBASE = 0x1100
          HANGUL_VBASE = 0x1161
          HANGUL_TBASE = 0x11A7
          HANGUL_LCOUNT = 19
          HANGUL_VCOUNT = 21
          HANGUL_TCOUNT = 28
          HANGUL_NCOUNT = HANGUL_VCOUNT * HANGUL_TCOUNT
          HANGUL_SCOUNT = 11172
          HANGUL_SLAST = HANGUL_SBASE + HANGUL_SCOUNT

          def in_char_class?(codepoint, classes)
            classes.detect { |c| database.boundary[c] === codepoint } ? true : false
          end

          def unpack_graphemes(string)
            codepoints = string.codepoints.to_a
            unpacked = []
            pos = 0
            marker = 0
            eoc = codepoints.length
            while (pos < eoc)
              pos += 1
              previous = codepoints[pos - 1]
              current = codepoints[pos]

              # See http://unicode.org/reports/tr29/#Grapheme_Cluster_Boundary_Rules
              should_break =
                if pos == eoc
                  true
                # GB3. CR X LF
                elsif previous == database.boundary[:cr] && current == database.boundary[:lf]
                  false
                # GB4. (Control|CR|LF) ÷
                elsif previous && in_char_class?(previous, [:control, :cr, :lf])
                  true
                # GB5. ÷ (Control|CR|LF)
                elsif in_char_class?(current, [:control, :cr, :lf])
                  true
                # GB6. L X (L|V|LV|LVT)
                elsif database.boundary[:l] === previous && in_char_class?(current, [:l, :v, :lv, :lvt])
                  false
                # GB7. (LV|V) X (V|T)
                elsif in_char_class?(previous, [:lv, :v]) && in_char_class?(current, [:v, :t])
                  false
                # GB8. (LVT|T) X (T)
                elsif in_char_class?(previous, [:lvt, :t]) && database.boundary[:t] === current
                  false
                # GB9. X (Extend | ZWJ)
                elsif in_char_class?(current, [:extend, :zwj])
                  false
                # GB9a. X SpacingMark
                elsif database.boundary[:spacingmark] === current
                  false
                # GB9b. Prepend X
                elsif database.boundary[:prepend] === previous
                  false
                # GB10. (E_Base | EBG) Extend* X E_Modifier
                elsif (marker...pos).any? { |i| in_char_class?(codepoints[i], [:e_base, :e_base_gaz]) && codepoints[i + 1...pos].all? { |c| database.boundary[:extend] === c } } && database.boundary[:e_modifier] === current
                  false
                # GB11. ZWJ X (Glue_After_Zwj | EBG)
                elsif database.boundary[:zwj] === previous && in_char_class?(current, [:glue_after_zwj, :e_base_gaz])
                  false
                # GB12. ^ (RI RI)* RI X RI
                # GB13. [^RI] (RI RI)* RI X RI
                elsif codepoints[marker..pos].all? { |c| database.boundary[:regional_indicator] === c } && codepoints[marker..pos].count { |c| database.boundary[:regional_indicator] === c }.even?
                  false
                # GB999. Any ÷ Any
                else
                  true
                end

              if should_break
                unpacked << codepoints[marker..pos - 1]
                marker = pos
              end
            end
            unpacked
          end

          def pack_graphemes(unpacked)
            unpacked.flatten.pack("U*")
          end

          def reorder_characters(codepoints)
            length = codepoints.length - 1
            pos = 0
            while pos < length do
              cp1, cp2 = database.codepoints[codepoints[pos]], database.codepoints[codepoints[pos + 1]]
              if (cp1.combining_class > cp2.combining_class) && (cp2.combining_class > 0)
                codepoints[pos..pos + 1] = cp2.code, cp1.code
                pos += (pos > 0 ? -1 : 1)
              else
                pos += 1
              end
            end
            codepoints
          end

          def decompose(type, codepoints)
            codepoints.inject([]) do |decomposed, cp|
              # if it's a hangul syllable starter character
              if HANGUL_SBASE <= cp && cp < HANGUL_SLAST
                sindex = cp - HANGUL_SBASE
                ncp = [] # new codepoints
                ncp << HANGUL_LBASE + sindex / HANGUL_NCOUNT
                ncp << HANGUL_VBASE + (sindex % HANGUL_NCOUNT) / HANGUL_TCOUNT
                tindex = sindex % HANGUL_TCOUNT
                ncp << (HANGUL_TBASE + tindex) unless tindex == 0
                decomposed.concat ncp
              # if the codepoint is decomposable in with the current decomposition type
              elsif (ncp = database.codepoints[cp].decomp_mapping) && (!database.codepoints[cp].decomp_type || type == :compatibility)
                decomposed.concat decompose(type, ncp.dup)
              else
                decomposed << cp
              end
            end
          end

          def compose(codepoints)
            pos = 0
            eoa = codepoints.length - 1
            starter_pos = 0
            starter_char = codepoints[0]
            previous_combining_class = -1
            while pos < eoa
              pos += 1
              lindex = starter_char - HANGUL_LBASE
              # -- Hangul
              if 0 <= lindex && lindex < HANGUL_LCOUNT
                vindex = codepoints[starter_pos + 1] - HANGUL_VBASE rescue vindex = -1
                if 0 <= vindex && vindex < HANGUL_VCOUNT
                  tindex = codepoints[starter_pos + 2] - HANGUL_TBASE rescue tindex = -1
                  if 0 <= tindex && tindex < HANGUL_TCOUNT
                    j = starter_pos + 2
                    eoa -= 2
                  else
                    tindex = 0
                    j = starter_pos + 1
                    eoa -= 1
                  end
                  codepoints[starter_pos..j] = (lindex * HANGUL_VCOUNT + vindex) * HANGUL_TCOUNT + tindex + HANGUL_SBASE
                end
                starter_pos += 1
                starter_char = codepoints[starter_pos]
              # -- Other characters
              else
                current_char = codepoints[pos]
                current = database.codepoints[current_char]
                if current.combining_class > previous_combining_class
                  if ref = database.composition_map[starter_char]
                    composition = ref[current_char]
                  else
                    composition = nil
                  end
                  unless composition.nil?
                    codepoints[starter_pos] = composition
                    starter_char = composition
                    codepoints.delete_at pos
                    eoa -= 1
                    pos -= 1
                    previous_combining_class = -1
                  else
                    previous_combining_class = current.combining_class
                  end
                else
                  previous_combining_class = current.combining_class
                end
                if current.combining_class == 0
                  starter_pos = pos
                  starter_char = codepoints[pos]
                end
              end
            end
            codepoints
          end

          def normalize(string, form = nil)
            form ||= @default_normalization_form
            # See http://www.unicode.org/reports/tr15, Table 1
            codepoints = string.codepoints.to_a
            case form
            when :d
              reorder_characters(decompose(:canonical, codepoints))
            when :c
              compose(reorder_characters(decompose(:canonical, codepoints)))
            when :kd
              reorder_characters(decompose(:compatibility, codepoints))
            when :kc
              compose(reorder_characters(decompose(:compatibility, codepoints)))
              else
              raise ArgumentError, "#{form} is not a valid normalization variant", caller
            end.pack("U*".freeze)
          end

          def downcase(string)
            apply_mapping string, :lowercase_mapping
          end

          def upcase(string)
            apply_mapping string, :uppercase_mapping
          end

          def swapcase(string)
            apply_mapping string, :swapcase_mapping
          end

          # Holds data about a codepoint in the Unicode database.
          class Codepoint
            attr_accessor :code, :combining_class, :decomp_type, :decomp_mapping, :uppercase_mapping, :lowercase_mapping

            # Initializing Codepoint object with default values
            def initialize
              @combining_class = 0
              @uppercase_mapping = 0
              @lowercase_mapping = 0
            end

            def swapcase_mapping
              uppercase_mapping > 0 ? uppercase_mapping : lowercase_mapping
            end
          end

          # Holds static data from the Unicode database.
          class UnicodeDatabase
            ATTRIBUTES = :codepoints, :composition_exclusion, :composition_map, :boundary, :cp1252

            attr_writer(*ATTRIBUTES)

            def initialize
              @codepoints = Hash.new(Codepoint.new)
              @composition_exclusion = []
              @composition_map = {}
              @boundary = {}
              @cp1252 = {}
            end

            # Lazy load the Unicode database so it's only loaded when it's actually used
            ATTRIBUTES.each do |attr_name|
              class_eval(<<-EOS, __FILE__, __LINE__ + 1)
                def #{attr_name}     # def codepoints
                  load               #   load
                  @#{attr_name}      #   @codepoints
                end                  # end
              EOS
            end

            # Loads the Unicode database and returns all the internal objects of
            # UnicodeDatabase.
            def load
              begin
                @codepoints, @composition_exclusion, @composition_map, @boundary, @cp1252 = File.open(self.class.filename, "rb") { |f| Marshal.load f.read }
              rescue => e
                raise IOError.new("Couldn't load the Unicode tables for UTF8Handler (#{e.message}), ActiveSupport::Multibyte is unusable")
              end

              # Redefine the === method so we can write shorter rules for grapheme cluster breaks
              @boundary.each_key do |k|
                @boundary[k].instance_eval do
                  def ===(other)
                    detect { |i| i === other } ? true : false
                  end
                end if @boundary[k].kind_of?(Array)
              end

              # define attr_reader methods for the instance variables
              class << self
                attr_reader(*ATTRIBUTES)
              end
            end

            # Returns the directory in which the data files are stored.
            def self.dirname
              File.expand_path("../../../values", __dir__)
            end

            # Returns the filename for the data file for this version.
            def self.filename
              File.expand_path File.join(dirname, "unicode_tables.dat")
            end
          end

          private

            def apply_mapping(string, mapping)
              database.codepoints
              string.each_codepoint.map do |codepoint|
                cp = database.codepoints[codepoint]
                if cp && (ncp = cp.send(mapping)) && ncp > 0
                  ncp
                else
                  codepoint
                end
              end.pack("U*")
            end

            def database
              @database ||= UnicodeDatabase.new
            end
        end
      end
    end
  end
end
