import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

/// A local SOCKS5 proxy server that listens on 127.0.0.1 without
/// authentication and forwards all traffic to a remote SOCKS5 proxy,
/// optionally with username/password authentication.
///
/// Architecture:
///   Browser → 127.0.0.1:[localPort] (no auth) → remoteHost:remotePort (with auth) → Internet
class LocalProxyServer {
  ServerSocket? _server;
  String? _remoteHost;
  int? _remotePort;
  String? _username;
  String? _password;
  int _localPort = 1080;

  bool get isRunning => _server != null;
  int get localPort => _localPort;

  /// Start local SOCKS5 server that forwards to remote proxy with auth.
  Future<bool> start({
    required String remoteHost,
    required int remotePort,
    String? username,
    String? password,
    int localPort = 1080,
  }) async {
    _remoteHost = remoteHost;
    _remotePort = remotePort;
    _username = username;
    _password = password;
    _localPort = localPort;

    try {
      _server = await ServerSocket.bind('127.0.0.1', localPort);
      _server!.listen(_handleClient);
      _log('Listening on 127.0.0.1:$_localPort');
      return true;
    } catch (e) {
      _log('Failed to start on port $localPort: $e');
      // Try any free port if preferred port is busy
      try {
        _server = await ServerSocket.bind('127.0.0.1', 0);
        _localPort = _server!.port;
        _server!.listen(_handleClient);
        _log('Listening on 127.0.0.1:$_localPort');
        return true;
      } catch (e2) {
        _log('Failed to start on any port: $e2');
        return false;
      }
    }
  }

  /// Stop the local proxy server.
  void stop() {
    _server?.close();
    _server = null;
    _log('Stopped');
  }

  /// Handle an incoming client connection from the browser/system.
  void _handleClient(Socket client) async {
    final clientBuf = _SocketBuffer(client);
    _SocketBuffer? remoteBuf;
    try {
      // 1. Receive SOCKS5 greeting from client (browser)
      final greeting = await clientBuf.readOnce();
      if (greeting.isEmpty || greeting[0] != 0x05) {
        clientBuf.destroy();
        return;
      }

      // 2. Reply: no auth required for local connections
      client.add([0x05, 0x00]);

      // 3. Receive connection request from client
      final request = await clientBuf.readOnce();
      if (request.length < 4 || request[0] != 0x05 || request[1] != 0x01) {
        clientBuf.destroy();
        return;
      }

      // Parse destination from client request
      String destHost;
      int destPort;
      int addrEnd;

      if (request[3] == 0x01) {
        // IPv4
        if (request.length < 10) {
          clientBuf.destroy();
          return;
        }
        destHost =
            '${request[4]}.${request[5]}.${request[6]}.${request[7]}';
        addrEnd = 8;
      } else if (request[3] == 0x03) {
        // Domain name
        if (request.length < 5) {
          clientBuf.destroy();
          return;
        }
        final len = request[4];
        if (request.length < 5 + len + 2) {
          clientBuf.destroy();
          return;
        }
        destHost = String.fromCharCodes(request.sublist(5, 5 + len));
        addrEnd = 5 + len;
      } else if (request[3] == 0x04) {
        // IPv6
        if (request.length < 22) {
          clientBuf.destroy();
          return;
        }
        destHost = request
            .sublist(4, 20)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(':');
        addrEnd = 20;
      } else {
        clientBuf.destroy();
        return;
      }
      destPort = (request[addrEnd] << 8) | request[addrEnd + 1];
      _log('Forwarding $destHost:$destPort via $_remoteHost:$_remotePort');

      // 4. Connect to REMOTE proxy with auth
      final remote = await Socket.connect(
        _remoteHost!,
        _remotePort!,
        timeout: const Duration(seconds: 10),
      );
      remoteBuf = _SocketBuffer(remote);

      // 5. SOCKS5 handshake with remote proxy
      if (_username != null && _username!.isNotEmpty) {
        // Offer username/password auth method (0x02)
        remote.add([0x05, 0x01, 0x02]);
        final remoteGreeting = await remoteBuf.readOnce();

        if (remoteGreeting.length >= 2 && remoteGreeting[1] == 0x02) {
          // Send username/password sub-negotiation
          final userBytes = _username!.codeUnits;
          final passBytes = (_password ?? '').codeUnits;
          remote.add([
            0x01,
            userBytes.length,
            ...userBytes,
            passBytes.length,
            ...passBytes,
          ]);
          final authResponse = await remoteBuf.readOnce();
          if (authResponse.length < 2 || authResponse[1] != 0x00) {
            _log('Remote auth failed');
            client.add([0x05, 0x01, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
            clientBuf.destroy();
            remoteBuf.destroy();
            return;
          }
        }
      } else {
        // No auth
        remote.add([0x05, 0x01, 0x00]);
        await remoteBuf.readOnce();
      }

      // 6. Send the actual connection request to remote proxy
      remote.add(request);
      final remoteResponse = await remoteBuf.readOnce();

      // 7. Forward remote response back to client
      client.add(remoteResponse);
      _log('Tunnel established for $destHost:$destPort');

      // 8. Bidirectional pipe — switch both buffers to raw pipe mode
      remoteBuf.pipeTo(client, onDone: () {
        try { client.destroy(); } catch (_) {}
      });
      clientBuf.pipeTo(remote, onDone: () {
        try { remote.destroy(); } catch (_) {}
      });
    } catch (e) {
      _log('Client error: $e');
      clientBuf.destroy();
      remoteBuf?.destroy();
    }
  }

  static void _log(String msg) {
    // ignore: avoid_print
    print('[LocalProxy] $msg');
  }
}

/// Wraps a [Socket] with a buffered read queue so that multiple sequential
/// [readOnce] calls during the SOCKS5 handshake never lose data between calls.
///
/// The socket is subscribed to **exactly once** in the constructor. Incoming
/// chunks are either delivered to a waiting [readOnce] caller, or queued for
/// the next call. After the handshake is complete, call [pipeTo] to switch to
/// direct pipe mode for maximum throughput — the single subscription continues
/// running but forwards data straight to the destination socket instead of
/// buffering it.
class _SocketBuffer {
  final Socket socket;
  final Queue<Completer<Uint8List>> _waiters = Queue();
  final Queue<Uint8List> _pending = Queue();
  late final StreamSubscription<Uint8List> _sub;
  bool _done = false;

  // Set by [pipeTo] to switch the subscription into direct-forwarding mode.
  Socket? _pipeTarget;
  void Function()? _pipeOnDone;

  _SocketBuffer(this.socket) {
    _sub = socket.listen(
      (data) {
        if (_pipeTarget != null) {
          // Pipe mode: forward directly to destination socket.
          try {
            _pipeTarget!.add(data);
          } catch (_) {
            // Destination closed; ignore — _pipeOnDone will be called on done.
          }
        } else if (_waiters.isNotEmpty) {
          final c = _waiters.removeFirst();
          if (!c.isCompleted) c.complete(Uint8List.fromList(data));
        } else {
          _pending.add(Uint8List.fromList(data));
        }
      },
      onError: (Object e) {
        _done = true;
        while (_waiters.isNotEmpty) {
          final c = _waiters.removeFirst();
          if (!c.isCompleted) c.complete(Uint8List(0));
        }
        _pipeOnDone?.call();
      },
      onDone: () {
        _done = true;
        while (_waiters.isNotEmpty) {
          final c = _waiters.removeFirst();
          if (!c.isCompleted) c.complete(Uint8List(0));
        }
        _pipeOnDone?.call();
      },
    );
  }

  /// Read exactly one chunk. Returns an empty [Uint8List] on timeout or error.
  Future<Uint8List> readOnce({Duration timeout = const Duration(seconds: 10)}) {
    if (_pending.isNotEmpty) {
      return Future.value(_pending.removeFirst());
    }
    if (_done) {
      return Future.value(Uint8List(0));
    }
    final c = Completer<Uint8List>();
    _waiters.add(c);
    return c.future.timeout(timeout, onTimeout: () {
      _waiters.remove(c);
      if (!c.isCompleted) c.complete(Uint8List(0));
      return Uint8List(0);
    });
  }

  /// Switch to pipe mode: all future data from this socket is forwarded
  /// directly to [dest]. Any chunks buffered before this call are flushed
  /// first. The underlying subscription is kept alive — no re-subscription
  /// is needed.
  void pipeTo(Socket dest, {void Function()? onDone}) {
    _pipeTarget = dest;
    _pipeOnDone = onDone;
    // Flush any data that arrived before pipeTo was called.
    while (_pending.isNotEmpty) {
      try {
        dest.add(_pending.removeFirst());
      } catch (_) {
        // Destination closed during flush; subsequent chunks will also fail
        // silently in the listener above.
      }
    }
  }

  void destroy() {
    _sub.cancel();
    try {
      socket.destroy();
    } catch (_) {}
  }
}
