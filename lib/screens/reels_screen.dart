import 'package:flutter/material.dart';
import 'package:lustra_ai/models/reel.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/upload_screen.dart';
import 'package:video_player/video_player.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: service.getReelsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'No reels available.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final allReels = snapshot.data!.map((data) => Reel.fromMap(data)).toList();
        // Filter out reels that have a null or empty prompt to prevent issues.
        final reels = allReels.where((reel) => reel.prompt.isNotEmpty).toList();

        if (reels.isEmpty) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'No valid reels with prompts available.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            itemBuilder: (context, index) {
              return ReelItem(reel: reels[index]);
            },
          ),
        );
      },
    );
  }
}

class ReelItem extends StatefulWidget {
  final Reel reel;

  const ReelItem({super.key, required this.reel});

  @override
  _ReelItemState createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
          _controller.setLooping(true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (!mounted) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          if (!_controller.value.isPlaying && _controller.value.isInitialized)
            Center(
              child: Icon(
                Icons.play_arrow,
                color: Colors.white.withOpacity(0.7),
                size: 80,
              ),
            ),
          _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.reel.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                ),
                if (widget.reel.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      widget.reel.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        shadows: [Shadow(blurRadius: 4)],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildSideActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSideActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            print('Reel Prompt: ${widget.reel.prompt}');
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UploadScreen(
                  shootType: 'PhotoShoot',
                  showTemplateSelection: true,
                  initialPrompt: widget.reel.prompt,
                ),
              ),
            );
          },
          icon: const Icon(Icons.add_circle_outline, size: 20),
          label: const Text('Add Yours'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.black.withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }
}
