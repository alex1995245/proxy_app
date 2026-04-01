import 'dart:async';
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
    try {
      // 1. Receive SOCKS5 greeting from client (browser)
      final greeting = await _readBytes(client);
      if (greeting.isEmpty || greeting[0] != 0x05) {
        client.close();
        return;
      }

      // 2. Reply: no auth required for local connections
      client.add([0x05, 0x00]);

      // 3. Receive connection request from client
      final request = await _readBytes(client);
      if (request.length < 4 || request[0] != 0x05 || request[1] != 0x01) {
        client.close();
        return;
      }

      // Parse destination from client request
      String destHost;
      int destPort;
      int addrEnd;

      if (request[3] == 0x01) {
        // IPv4
        if (request.length < 10) {
          client.close();
          return;
        }
        destHost =
            '${request[4]}.${request[5]}.${request[6]}.${request[7]}';
        addrEnd = 8;
      } else if (request[3] == 0x03) {
        // Domain name
        if (request.length < 5) {
          client.close();
          return;
        }
        final len = request[4];
        if (request.length < 5 + len + 2) {
          client.close();
          return;
        }
        destHost = String.fromCharCodes(request.sublist(5, 5 + len));
        addrEnd = 5 + len;
      } else if (request[3] == 0x04) {
        // IPv6
        if (request.length < 22) {
          client.close();
          return;
        }
        destHost = request
            .sublist(4, 20)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(':');
        addrEnd = 20;
      } else {
        client.close();
        return;
      }
      destPort = (request[addrEnd] << 8) | request[addrEnd + 1];
      _log('Forwarding $destHost:$destPort via $_remoteHost:$_remotePort');

      // 4. Connect to REMOTE proxy with auth
      final remote = await Socket.connect(_remoteHost!, _remotePort!);

      // 5. SOCKS5 handshake with remote proxy
      if (_username != null && _username!.isNotEmpty) {
        // Offer username/password auth method (0x02)
        remote.add([0x05, 0x01, 0x02]);
        final remoteGreeting = await _readBytes(remote);

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
          final authResponse = await _readBytes(remote);
          if (authResponse.length < 2 || authResponse[1] != 0x00) {
            _log('Remote auth failed');
            client.add([0x05, 0x01, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
            client.close();
            remote.close();
            return;
          }
        }
      } else {
        // No auth
        remote.add([0x05, 0x01, 0x00]);
        await _readBytes(remote);
      }

      // 6. Send the actual connection request to remote proxy
      remote.add(request);
      final remoteResponse = await _readBytes(remote);

      // 7. Forward remote response back to client
      client.add(remoteResponse);

      // 8. Bidirectional pipe — forward all subsequent data
      client.listen(
        (data) {
          try {
            remote.add(data);
          } catch (e) {
            _log('client→remote pipe error: $e');
          }
        },
        onDone: () => remote.close(),
        onError: (Object e) {
          _log('client stream error: $e');
          remote.close();
        },
      );
      remote.listen(
        (data) {
          try {
            client.add(data);
          } catch (e) {
            _log('remote→client pipe error: $e');
          }
        },
        onDone: () => client.close(),
        onError: (Object e) {
          _log('remote stream error: $e');
          client.close();
        },
      );
    } catch (e) {
      _log('Client error: $e');
      try {
        client.close();
      } catch (_) {}
    }
  }

  /// Read the next available chunk from [socket] with a 10-second timeout.
  Future<Uint8List> _readBytes(Socket socket) async {
    final completer = Completer<Uint8List>();
    late StreamSubscription<Uint8List> sub;
    sub = socket.listen(
      (data) {
        if (!completer.isCompleted) {
          sub.cancel();
          completer.complete(Uint8List.fromList(data));
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) {
          sub.cancel();
          completer.complete(Uint8List(0));
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(Uint8List(0));
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        sub.cancel();
        return Uint8List(0);
      },
    );
  }

  static void _log(String msg) {
    // ignore: avoid_print
    print('[LocalProxy] $msg');
  }
}
