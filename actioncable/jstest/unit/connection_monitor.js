require('../test_helper');

describe('ActionCable.ConnectionMonitor', function() {
  describe('Public API', function() {
    describe('#isRunning()', function() {
      it('returns a boolean', function() {
      });
    });

    describe('#new()', function() {
      it('', function() {
      });
    });

    describe('#recordConnect()', function() {
      it('records a ping and logs', function() {
      });
    });

    describe('#recordDisconnect()', function() {
      it('sets disconnectedAt and logs', function() {
      });
    });

    describe('#recordPing()', function() {
      it('sets pingedAt to the current time', function() {
      });
    });

    describe('#start()', function() {
      it('no-ops if isRunning()', function() {
      });

      it('starts to poll and logs', function() {
      });
    });

    describe('#stop()', function() {
      it('no-ops if not currently running', function() {
      });

      it('stops polling and logs', function() {
      });
    });
  });

  describe('Private API', function() {
    describe('#clamp()', function() {
      it('', function() {
      });
    });

    describe('#connectionIsStale()', function() {
      it('', function() {
      });
    });

    describe('#disconnectedRecently()', function() {
      it('', function() {
      });
    });

    describe('#getPollInterval()', function() {
      it('', function() {
      });
    });

    describe('#now()', function() {
      it('', function() {
      });
    });

    describe('#poll()', function() {
      it('', function() {
      });
    });

    describe('#pollInterval', function() {
      it('', function() {
      });
    });

    describe('#reconnectIfStale()', function() {
      it('', function() {
      });
    });

    describe('#secondsSince()', function() {
      it('', function() {
      });
    });

    describe('#staleThreshold', function() {
      it('', function() {
      });
    });

    describe('#startPolling()', function() {
      it('', function() {
      });
    });

    describe('#stopPolling()', function() {
      it('', function() {
      });
    });

    describe('#visibilityDidChange()', function() {
      it('', function() {
      });
    });
  });
});
