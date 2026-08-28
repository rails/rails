# frozen_string_literal: true

# :markup: markdown

# The ThumbHash codec in this file is adapted from https://github.com/evanw/thumbhash.
# Copyright (c) 2023 Evan Wallace
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require "base64"
require "zlib"

module ActiveStorage
  module ImagePlaceholder # :nodoc:
    MAX_SIZE = 16

    class << self
      def data_url(width, height, rgba)
        hash = rgba_to_thumb_hash(width, height, rgba)
        width, height, rgba = thumb_hash_to_rgba(hash)
        rgba_to_data_url(width, height, rgba)
      end

      private
        def rgba_to_thumb_hash(width, height, rgba)
          average_red = average_green = average_blue = average_alpha = 0.0

          (width * height).times do |index|
            offset = index * 4
            alpha = rgba[offset + 3] / 255.0
            average_red += alpha * rgba[offset] / 255.0
            average_green += alpha * rgba[offset + 1] / 255.0
            average_blue += alpha * rgba[offset + 2] / 255.0
            average_alpha += alpha
          end

          if average_alpha > 0
            average_red /= average_alpha
            average_green /= average_alpha
            average_blue /= average_alpha
          end

          has_alpha = average_alpha < width * height
          luminance_limit = has_alpha ? 5 : 7
          luminance_x = [ 1, (luminance_limit * width.to_f / [ width, height ].max).round ].max
          luminance_y = [ 1, (luminance_limit * height.to_f / [ width, height ].max).round ].max
          luminance = Array.new(width * height)
          yellow_blue = Array.new(width * height)
          red_green = Array.new(width * height)
          alpha = Array.new(width * height)

          (width * height).times do |index|
            offset = index * 4
            pixel_alpha = rgba[offset + 3] / 255.0
            red = average_red * (1 - pixel_alpha) + pixel_alpha * rgba[offset] / 255.0
            green = average_green * (1 - pixel_alpha) + pixel_alpha * rgba[offset + 1] / 255.0
            blue = average_blue * (1 - pixel_alpha) + pixel_alpha * rgba[offset + 2] / 255.0
            luminance[index] = (red + green + blue) / 3
            yellow_blue[index] = (red + green) / 2 - blue
            red_green[index] = red - green
            alpha[index] = pixel_alpha
          end

          luminance_dc, luminance_ac, luminance_scale = encode_channel(luminance, [ 3, luminance_x ].max, [ 3, luminance_y ].max, width, height)
          yellow_blue_dc, yellow_blue_ac, yellow_blue_scale = encode_channel(yellow_blue, 3, 3, width, height)
          red_green_dc, red_green_ac, red_green_scale = encode_channel(red_green, 3, 3, width, height)
          alpha_dc, alpha_ac, alpha_scale = has_alpha ? encode_channel(alpha, 5, 5, width, height) : []

          landscape = width > height
          header24 = (63 * luminance_dc).round |
            ((31.5 + 31.5 * yellow_blue_dc).round << 6) |
            ((31.5 + 31.5 * red_green_dc).round << 12) |
            ((31 * luminance_scale).round << 18) |
            (has_alpha ? (1 << 23) : 0)
          header16 = (landscape ? luminance_y : luminance_x) |
            ((63 * yellow_blue_scale).round << 3) |
            ((63 * red_green_scale).round << 9) |
            (landscape ? (1 << 15) : 0)
          hash = [ header24 & 255, (header24 >> 8) & 255, header24 >> 16, header16 & 255, header16 >> 8 ]
          hash << ((15 * alpha_dc).round | ((15 * alpha_scale).round << 4)) if has_alpha

          channels = has_alpha ? [ luminance_ac, yellow_blue_ac, red_green_ac, alpha_ac ] : [ luminance_ac, yellow_blue_ac, red_green_ac ]
          channels.flatten.each_with_index do |factor, index|
            hash_index = (has_alpha ? 6 : 5) + (index >> 1)
            hash[hash_index] ||= 0
            hash[hash_index] |= (15 * factor).round << ((index & 1) << 2)
          end

          hash
        end

        def encode_channel(channel, channel_width, channel_height, width, height)
          dc = scale = 0.0
          ac = []
          factors_x = Array.new(width)

          channel_height.times do |channel_y|
            channel_x = 0
            while channel_x * channel_height < channel_width * (channel_height - channel_y)
              factor = 0.0
              width.times do |x|
                factors_x[x] = Math.cos(Math::PI / width * channel_x * (x + 0.5))
              end
              height.times do |y|
                factor_y = Math.cos(Math::PI / height * channel_y * (y + 0.5))
                width.times { |x| factor += channel[x + y * width] * factors_x[x] * factor_y }
              end
              factor /= width * height

              if channel_x.zero? && channel_y.zero?
                dc = factor
              else
                ac << factor
                scale = [ scale, factor.abs ].max
              end
              channel_x += 1
            end
          end

          ac.map! { |factor| 0.5 + 0.5 / scale * factor } if scale > 0
          [ dc, ac, scale ]
        end

        def thumb_hash_to_rgba(hash)
          header24 = hash[0] | (hash[1] << 8) | (hash[2] << 16)
          header16 = hash[3] | (hash[4] << 8)
          luminance_dc = (header24 & 63) / 63.0
          yellow_blue_dc = ((header24 >> 6) & 63) / 31.5 - 1
          red_green_dc = ((header24 >> 12) & 63) / 31.5 - 1
          luminance_scale = ((header24 >> 18) & 31) / 31.0
          has_alpha = (header24 >> 23) != 0
          yellow_blue_scale = ((header16 >> 3) & 63) / 63.0
          red_green_scale = ((header16 >> 9) & 63) / 63.0
          landscape = (header16 >> 15) != 0
          luminance_x = [ 3, landscape ? (has_alpha ? 5 : 7) : header16 & 7 ].max
          luminance_y = [ 3, landscape ? header16 & 7 : (has_alpha ? 5 : 7) ].max
          alpha_dc = has_alpha ? (hash[5] & 15) / 15.0 : 1.0
          alpha_scale = has_alpha ? (hash[5] >> 4) / 15.0 : 0.0
          ac_start = has_alpha ? 6 : 5
          ac_index = 0

          decode_channel = ->(channel_width, channel_height, scale) do
            factors = []
            channel_height.times do |channel_y|
              channel_x = channel_y.zero? ? 1 : 0
              while channel_x * channel_height < channel_width * (channel_height - channel_y)
                value = hash[ac_start + (ac_index >> 1)]
                factors << (((value >> ((ac_index & 1) << 2)) & 15) / 7.5 - 1) * scale
                ac_index += 1
                channel_x += 1
              end
            end
            factors
          end

          luminance_ac = decode_channel.call(luminance_x, luminance_y, luminance_scale)
          yellow_blue_ac = decode_channel.call(3, 3, yellow_blue_scale * 1.25)
          red_green_ac = decode_channel.call(3, 3, red_green_scale * 1.25)
          alpha_ac = decode_channel.call(5, 5, alpha_scale) if has_alpha
          ratio = luminance_x.to_f / luminance_y
          width = (ratio > 1 ? MAX_SIZE : MAX_SIZE * ratio).round
          height = (ratio > 1 ? MAX_SIZE / ratio : MAX_SIZE).round
          rgba = Array.new(width * height * 4, 0)
          factors_x = []
          factors_y = []

          height.times do |y|
            width.times do |x|
              luminance = luminance_dc
              yellow_blue = yellow_blue_dc
              red_green = red_green_dc
              alpha = alpha_dc

              [ luminance_x, has_alpha ? 5 : 3 ].max.times do |channel_x|
                factors_x[channel_x] = Math.cos(Math::PI / width * (x + 0.5) * channel_x)
              end
              [ luminance_y, has_alpha ? 5 : 3 ].max.times do |channel_y|
                factors_y[channel_y] = Math.cos(Math::PI / height * (y + 0.5) * channel_y)
              end

              index = 0
              luminance_y.times do |channel_y|
                channel_x = channel_y.zero? ? 1 : 0
                while channel_x * luminance_y < luminance_x * (luminance_y - channel_y)
                  luminance += luminance_ac[index] * factors_x[channel_x] * factors_y[channel_y] * 2
                  index += 1
                  channel_x += 1
                end
              end

              index = 0
              3.times do |channel_y|
                channel_x = channel_y.zero? ? 1 : 0
                while channel_x < 3 - channel_y
                  factor = factors_x[channel_x] * factors_y[channel_y] * 2
                  yellow_blue += yellow_blue_ac[index] * factor
                  red_green += red_green_ac[index] * factor
                  index += 1
                  channel_x += 1
                end
              end

              if has_alpha
                index = 0
                5.times do |channel_y|
                  channel_x = channel_y.zero? ? 1 : 0
                  while channel_x < 5 - channel_y
                    alpha += alpha_ac[index] * factors_x[channel_x] * factors_y[channel_y] * 2
                    index += 1
                    channel_x += 1
                  end
                end
              end

              blue = luminance - 2.0 / 3 * yellow_blue
              red = (3 * luminance - blue + red_green) / 2
              green = red - red_green
              offset = (x + y * width) * 4
              rgba[offset] = (255 * red.clamp(0, 1)).to_i
              rgba[offset + 1] = (255 * green.clamp(0, 1)).to_i
              rgba[offset + 2] = (255 * blue.clamp(0, 1)).to_i
              rgba[offset + 3] = (255 * alpha.clamp(0, 1)).to_i
            end
          end

          [ width, height, rgba ]
        end

        def rgba_to_data_url(width, height, rgba)
          pixels = String.new(capacity: height * (width * 4 + 1), encoding: Encoding::BINARY)
          previous_row = Array.new(width * 4, 0)
          height.times do |y|
            row = rgba.slice(y * width * 4, width * 4)
            filter, filtered = png_filter(row, previous_row)
            pixels << filter.chr << filtered.pack("C*")
            previous_row = row
          end

          header = [ width, height, 8, 6, 0, 0, 0 ].pack("NNC5")
          png = "\x89PNG\r\n\x1a\n".b + png_chunk("IHDR", header) + png_chunk("IDAT", Zlib::Deflate.deflate(pixels, Zlib::BEST_COMPRESSION)) + png_chunk("IEND", "")
          "data:image/png;base64,#{Base64.strict_encode64(png)}"
        end

        def png_filter(row, previous_row)
          filters = 5.times.map do |type|
            row.each_index.map do |index|
              left = index >= 4 ? row[index - 4] : 0
              above = previous_row[index]
              upper_left = index >= 4 ? previous_row[index - 4] : 0
              predictor = case type
              when 0 then 0
              when 1 then left
              when 2 then above
              when 3 then (left + above) / 2
              when 4 then paeth_predictor(left, above, upper_left)
              end
              (row[index] - predictor) & 255
            end
          end
          type = filters.each_index.min_by { |index| filters[index].sum { |byte| [ byte, 256 - byte ].min } }
          [ type, filters[type] ]
        end

        def paeth_predictor(left, above, upper_left)
          prediction = left + above - upper_left
          distances = [ (prediction - left).abs, (prediction - above).abs, (prediction - upper_left).abs ]
          [ left, above, upper_left ][distances.each_index.min_by { |index| distances[index] }]
        end

        def png_chunk(type, data)
          [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N")
        end
    end
  end
end
