def silence_warnings
  old_verbose, $VERBOSE = $VERBOSE, nil
  begin
    yield
  ensure
    $VERBOSE = old_verbose
  end
end
