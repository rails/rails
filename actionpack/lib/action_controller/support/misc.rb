def silence_warnings
  old_verbose, $VERBOSE = $VERBOSE, nil
  result = yield
  $VERBOSE = old_verbose
  return result
end
