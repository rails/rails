module ActionDispatch
  # These are internal constants used to avoid repeated object allocation
  # in performance hot spots.
  #
  # This is a necessarily ugly setup, not a best practice to emulate.
  #
  # When Rails is on Ruby 2.1+, we'll be able to lean on its treatment of
  # repeated 'foo'.freeze as identical objects. That's ugly too, but it's
  # clearer than collecting a big bag of string constants.
  #
  # Please don't add every constant string here. Just those that get reused
  # in multiple modules. Leave module-specific strings in those files, close
  # to home where they're relevant to the code that relies on them.
  module Strings #:nodoc:
    COLON = ':'.freeze
    COMMA = ','.freeze
    EMPTY = ''.freeze
    EQUALS = '='.freeze
    HASH = '#'.freeze
    HYPHEN = '-'.freeze
    NEW = 'new'.freeze
    NEWLINE = "\n".freeze
    PERIOD = '.'.freeze
    QUESTION_MARK = '?'.freeze
    SEMICOLON = ';'.freeze
    SLASH = '/'.freeze
    SPACE = ' '.freeze
    UNDERSCORE = '_'.freeze
  end
  private_constant :Strings
end
