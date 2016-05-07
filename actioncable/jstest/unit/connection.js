require('../test_helper');

describe('ActionCable.Connection', function() {
  describe('Public API', function() {
    describe('#getProtocol()', function() {
      it("returns the socket's protocol", function() {
      });
    });

    describe('#isActive()', function() {
      it('returns a boolean', function() {
      });
    });

    describe('#isOpen()', function() {
      it('returns a boolean', function() {
      });
    });

    describe('#open()', function() {
      it('closes the WebSocket connection', function() {
      });
    });

    describe('#new()', function() {
      it('', function() {
      });
    });

    describe('#open()', function() {
      it('errors if already active', function() {
      });

      it('creates a new WebSocket and logs', function() {
      });
    });

    describe('#reopen()', function() {
      it('', function() {
      });
    });

    describe('#send()', function() {
      it('JSON-ifies data and sends it down the socket', function() {
      });
    });
  });

  describe('Private API', function() {
    describe('#events', function() {
      describe('#message()', function() {
        it('dispatches', function() {
        });
      });

      describe('#close()', function() {
        it('logs', function() {
        });
      });

      describe('#error()', function() {
        it('logs', function() {
        });
      });

      describe('#open()', function() {
        it('logs', function() {
        });
      });
    });

    describe('#isProtocolSupported()', function() {
      it('returns a boolean', function() {
      });
    });

    describe('#isState()', function() {
      it('returns a boolean', function() {
      });
    });

    describe('#uninstallEventHandlers()', function() {
      it('removes event handler from the chain', function() {
      });
    });
  });
});
