*   Action Cable has been updated to include protections against thundering herd of reconenctions:

    * On connection loss the inital interval is a random number of seconds between the min and max poll interval. 
    * Successive reconnections will use the logarithmic backoff. 

    *John Williams*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/actioncable/CHANGELOG.md) for previous changes.
