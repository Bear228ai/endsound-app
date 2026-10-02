import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EndSoundApp());
}

class EndSoundApp extends StatelessWidget {
  const EndSoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EndSound',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF09070F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF9D4EDD),
          surface: Color(0xFF140F22),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioPlayer _player = AudioPlayer();
  String serverUrl = "https://volumes-pierce-evident-cycle.trycloudflare.com";
  List<dynamic> tracks = [];
  String currentTrackId = "";
  String currentTitle = "Ничего не играет";
  String currentArtist = "";
  bool isPlaying = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => isPlaying = state.playing);
      }
    });
  }

  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('server_url');
    if (saved != null && saved.isNotEmpty) {
      serverUrl = saved;
    }
    fetchTracks();
  }

  Future<void> _saveServerUrl(String url) async {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith("/")) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', cleanUrl);
    setState(() {
      serverUrl = cleanUrl;
    });
    fetchTracks();
  }

  Future<void> fetchTracks() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('$serverUrl/tracks')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        setState(() => tracks = jsonDecode(res.body));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF231834),
            content: Text("Ошибка подключения: $e", style: const TextStyle(color: Colors.white70)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> playTrack(String id, String title, String artist) async {
    try {
      currentTrackId = id;
      currentTitle = title;
      currentArtist = artist;
      await _player.setUrl('$serverUrl/stream/$id');
      _player.play();
      setState(() {});
    } catch (e) {
      debugPrint("Playback error: $e");
    }
  }

  Future<void> uploadSong() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );

    if (result != null && result.files.single.path != null) {
      try {
        var request = http.MultipartRequest('POST', Uri.parse('$serverUrl/upload'));
        request.files.add(await http.MultipartFile.fromPath('file', result.files.single.path!));
        var res = await request.send();
        if (res.statusCode == 200) {
          fetchTracks();
        }
      } catch (e) {
        debugPrint("Upload error: $e");
      }
    }
  }

  void openSettingsDialog() {
    final controller = TextEditingController(text: serverUrl);
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: const Color(0xFF191226).withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: const Color(0xFF9D4EDD).withOpacity(0.3)),
          ),
          title: const Text("Сервер EndSound", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Введи ссылку Cloudflare или свой домен:", style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF261D3B),
                  hintText: "https://...trycloudflare.com",
                  hintStyle: const TextStyle(color: Colors.white30),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Отмена", style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D4EDD),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                _saveServerUrl(controller.text);
                Navigator.pop(ctx);
              },
              child: const Text("Сохранить", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: const Color(0xFF09070F).withOpacity(0.6)),
          ),
        ),
        title: const Text(
          "EndSound",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFFC77DFF)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFC77DFF), size: 26),
            onPressed: uploadSong,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: openSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: fetchTracks,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Матовый фон с фиолетовым свечением
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7B2CBF).withOpacity(0.18),
              ),
            ),
          ),
          SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF9D4EDD)))
                : tracks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.music_off, size: 50, color: Colors.white24),
                            const SizedBox(height: 12),
                            const Text("Нет доступных треков", style: TextStyle(color: Colors.white54)),
                            TextButton(
                              onPressed: openSettingsDialog,
                              child: const Text("Проверить адрес сервера", style: TextStyle(color: Color(0xFF9D4EDD))),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 90),
                        itemCount: tracks.length,
                        itemBuilder: (context, index) {
                          final t = tracks[index];
                          final bool isCurrent = currentTrackId == t['id'];

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161024).withOpacity(0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCurrent ? const Color(0xFF9D4EDD) : Colors.white.withOpacity(0.04),
                              ),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF241A38),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.music_note, color: Color(0xFFC77DFF)),
                              ),
                              title: Text(
                                t['title'] ?? 'Без названия',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                t['artist'] ?? 'Неизвестен',
                                style: const TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  isCurrent && isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                  color: const Color(0xFF9D4EDD),
                                  size: 34,
                                ),
                                onPressed: () {
                                  if (isCurrent && isPlaying) {
                                    _player.pause();
                                  } else {
                                    playTrack(t['id'], t['title'], t['artist']);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Нижний плавающий матовый плеер
          if (currentTrackId.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1433).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.album, size: 40, color: Color(0xFFC77DFF)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(currentTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                              Text(currentArtist, style: const TextStyle(color: Colors.white38, fontSize: 11), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                          onPressed: () => isPlaying ? _player.pause() : _player.play(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
