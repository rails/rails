# encoding: utf-8

module ActiveSupport #:nodoc:
  module Multibyte #:nodoc:
    # Holds data about a codepoint in the Unicode database
    class Codepoint
      attr_accessor :code, :combining_class, :decomp_type, :decomp_mapping, :uppercase_mapping, :lowercase_mapping
    end

    # Holds static data from the Unicode database
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

      # Loads the Unicode database and returns all the internal objects of UnicodeDatabase.
      def load
        begin
          @codepoints, @composition_exclusion, @composition_map, @boundary, @cp1252 = File.open(self.class.filename, 'rb') { |f| Marshal.load f.read }
        rescue Exception => e
            raise IOError.new("Couldn't load the Unicode tables for UTF8Handler (#{e.message}), ActiveSupport::Multibyte is unusable")
        end

        # Redefine the === method so we can write shorter rules for grapheme cluster breaks
        @boundary.each do |k,_|
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

      # Returns the directory in which the data files are stored
      def self.dirname
        File.dirname(__FILE__) + '/../values/'
      end

      # Returns the filename for the data file for this version
      def self.filename
        File.expand_path File.join(dirname, "unicode_tables.dat")
      end
    end

    # UniCode Database
    UCD = UnicodeDatabase.new
  end
end