import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nostr_tools/nostr_tools.dart';

void main() {
  runApp(anonstr());
}

class anonstr extends StatefulWidget {
  @override
  _anonstrState createState() => _anonstrState();
}

class _anonstrState extends State<anonstr> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'anonstr',
      theme: _isDarkMode ? _buildDarkTheme() : _buildLightTheme(),
      home: NostrHomePage(
        toggleDarkMode: _toggleDarkMode,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData.light().copyWith(
      colorScheme: const ColorScheme.light(
        primary: Colors.brown,
        secondary: Colors.orange,
        surface: Colors.white,
        error: Colors.red,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.black,
        onError: Colors.white,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      colorScheme: ColorScheme.dark(
        primary: Colors.yellow.shade700,
        secondary: Colors.orange,
        surface: Colors.grey.shade800,
        error: Colors.red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
    );
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }
}

class NostrHomePage extends StatefulWidget {
  final VoidCallback toggleDarkMode;

  const NostrHomePage({required this.toggleDarkMode});

  @override
  _NostrHomePageState createState() => _NostrHomePageState();
}

class _NostrHomePageState extends State<NostrHomePage> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? _noteIdNip19;
  bool _isLoading = false;

  final List<String> relays = [
    'wss://strfry.iris.to',
    'wss://relay.damus.io',
    'wss://relay.nostr.band',
    'wss://relay.snort.social',
    'wss://vitor.nostr1.com',
    'wss://nos.lol',
    'wss://untreu.me'
  ];

  Future<void> _broadcastNote() async {
    setState(() {
      _isLoading = true;
    });

    final keyApi = KeyApi();
    final eventApi = EventApi();
    final nip19 = Nip19();

    final privateKey = keyApi.generatePrivateKey();
    final publicKey = keyApi.getPublicKey(privateKey);

    final displayName = _nameController.text.isNotEmpty ? _nameController.text : "anonstr";
    final noteContent = _noteController.text.isNotEmpty ? _noteController.text : "github.com/untreu2";

    final metadataEvent = Event(
      kind: 0,
      tags: [],
      content: jsonEncode({
        'name': displayName,
      }),
      created_at: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      pubkey: publicKey,
    );

    metadataEvent.id = eventApi.getEventHash(metadataEvent);
    metadataEvent.sig = eventApi.signEvent(metadataEvent, privateKey);

    final noteEvent = Event(
      kind: 1,
      tags: [],
      content: noteContent,
      created_at: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      pubkey: publicKey,
    );

    noteEvent.id = eventApi.getEventHash(noteEvent);
    noteEvent.sig = eventApi.signEvent(noteEvent, privateKey);

    bool success = false;

    for (var relayUrl in relays) {
      final relay = RelayApi(relayUrl: relayUrl);
      try {
        final stream = await relay.connect();

        relay.on((event) {
          if (event == RelayEvent.connect) {
            print('[+] connected to $relayUrl');
          } else if (event == RelayEvent.error) {
            print('[!] failed to connect to $relayUrl');
          }
        });

        relay.publish(metadataEvent);
        relay.publish(noteEvent);

        await for (Message message in stream) {
          if (message.type == 'OK') {
            print('[+] Event Published on $relayUrl: ${message.message}');
            success = true;
            break;
          }
        }

        if (success) {
          break;
        }

        await Future.delayed(const Duration(seconds: 5));
        relay.close();
      } catch (e) {
        print('[!] Error connecting to $relayUrl: $e');
      }
    }

    if (success) {
      _noteIdNip19 = nip19.noteEncode(noteEvent.id);
      _showNoteIdDialog(_noteIdNip19!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to publish note to any relay')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _copyToClipboard(String noteId) {
    Clipboard.setData(ClipboardData(text: noteId)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note ID copied to clipboard')),
      );
    });
  }

  void _showNoteIdDialog(String noteId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Note published successfully!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(noteId),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  _copyToClipboard(noteId);
                },
                child: const Text('Copy Note ID'),
              ),
            ],
          ),
          actions: [


          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('anonstr'),
        leading: IconButton(
          icon: const Icon(Icons.favorite),
          onPressed: _showDonateDialog,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb),
            onPressed: widget.toggleDarkMode,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 165),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Enter your note',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Enter your display name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 165),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _broadcastNote,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Share'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDonateDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(child: Text('Donate')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Row(
                children: const [
                  Expanded(child: Text('Lightning:')),
                ],
              ),
              Row(
                children: [
                  const Expanded(child: Text('untreu@walletofsatoshi.com')),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: 'untreu@walletofsatoshi.com')).then((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied.'),
                          ),
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Expanded(child: Text("On-chain:")),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: SelectableText('bc1qr2zfelma4vmsnwhyn88yctfxjtmu2d0xs55eh3'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: 'bc1qr2zfelma4vmsnwhyn88yctfxjtmu2d0xs55eh3')).then((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied.'),
                          ),
                        );
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Center(child: Text('Close')),
            ),
          ],
        );
      },
    );
  }
}
