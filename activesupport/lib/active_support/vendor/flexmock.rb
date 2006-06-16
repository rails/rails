#!/usr/bin/env ruby

#---
# Copyright 2003, 2004 by Jim Weirich (jim@weriichhouse.org).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require 'test/unit'

# FlexMock is a flexible mock object suitable for using with Ruby's
# Test::Unit unit test framework.  FlexMock has a simple interface
# that's easy to remember, and leaves the hard stuff to all those
# other mock object implementations.
#
# Usage:  See TestSamples for example usage.

class FlexMock
  include Test::Unit::Assertions

  # Create a FlexMock object.
  def initialize
    @handlers = Hash.new
    @counts   = Hash.new(0)
    @expected_counts = Hash.new
  end
  
  # Handle all messages denoted by +sym+ by calling the given block
  # and passing any parameters to the block.  If we know exactly how
  # many calls are to be made to a particular method, we may check
  # that by passing in the number of expected calls as a second
  # paramter.
  def mock_handle(sym, expected_count=nil, &block)
    if block_given?
      @handlers[sym] = block
    else
      @handlers[sym] = proc { }
    end
    @expected_counts[sym] = expected_count  if expected_count
  end

  # Verify that each method that had an explicit expected count was
  # actually called that many times.
  def mock_verify
    @expected_counts.keys.each do |key|
      assert_equal @expected_counts[key], @counts[key],
	"Expected method #{key} to be called #{@expected_counts[key]} times, " +
	"got #{@counts[key]}"
    end
  end

  # Report how many times a method was called.
  def mock_count(sym)
    @counts[sym]
  end

  # Ignore all undefined (missing) method calls.
  def mock_ignore_missing
    @ignore_missing = true
  end

  # Handle missing methods by attempting to look up a handler.
  def method_missing(sym, *args, &block)
    if handler = @handlers[sym]
      @counts[sym] += 1
      args << block  if block_given?
      handler.call(*args)
    else
      super(sym, *args, &block)  unless @ignore_missing
    end
  end

  # Class method to make sure that verify is called at the end of a
  # test.
  def self.use
    mock = new
    yield mock
  ensure
    mock.mock_verify
  end
end
