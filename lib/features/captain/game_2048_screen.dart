import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/colors.dart';

/// A simple 2048 puzzle - something for a captain to kill a few minutes
/// with while idle between requests, entirely offline/self-contained (no
/// network, no new backend). Swipe the board in any direction; matching
/// tiles merge, reach 2048 to win (can keep playing after).
class Game2048Screen extends StatefulWidget {
  const Game2048Screen({super.key});

  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

enum _Direction { up, down, left, right }

class _Game2048ScreenState extends State<Game2048Screen> {
  static const int _size = 4;
  static const _bestScoreKey = 'game_2048_best_score';

  late List<List<int>> _grid;
  int _score = 0;
  int _bestScore = 0;
  bool _gameOver = false;
  bool _won = false;
  // Once the captain dismisses the "you won" banner, let them keep playing
  // past 2048 without it popping up again every single merge.
  bool _wonBannerDismissed = false;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _loadBestScore();
    _startNewGame();
  }

  Future<void> _loadBestScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_bestScoreKey);
      if (saved != null && mounted) setState(() => _bestScore = saved);
    } catch (_) {
      // Best-effort - just starts at 0 if this fails.
    }
  }

  Future<void> _saveBestScoreIfNeeded() async {
    if (_score <= _bestScore) return;
    setState(() => _bestScore = _score);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestScoreKey, _score);
    } catch (_) {
      // Best-effort - the in-memory high score still shows either way.
    }
  }

  void _startNewGame() {
    _grid = List.generate(_size, (_) => List.filled(_size, 0));
    _score = 0;
    _gameOver = false;
    _won = false;
    _wonBannerDismissed = false;
    _spawnTile();
    _spawnTile();
    setState(() {});
  }

  void _spawnTile() {
    final empty = <Point<int>>[];
    for (var r = 0; r < _size; r++) {
      for (var c = 0; c < _size; c++) {
        if (_grid[r][c] == 0) empty.add(Point(r, c));
      }
    }
    if (empty.isEmpty) return;
    final cell = empty[_random.nextInt(empty.length)];
    _grid[cell.x][cell.y] = _random.nextDouble() < 0.9 ? 2 : 4;
  }

  // Slides+merges a single line (already ordered from the direction the
  // player is moving toward) - the same merge rule for all 4 directions,
  // just fed a differently-extracted/ordered line each time.
  List<int> _mergeLine(List<int> line) {
    final nonZero = line.where((v) => v != 0).toList();
    final merged = <int>[];
    var i = 0;
    while (i < nonZero.length) {
      if (i + 1 < nonZero.length && nonZero[i] == nonZero[i + 1]) {
        final value = nonZero[i] * 2;
        merged.add(value);
        _score += value;
        if (value == 2048) _won = true;
        i += 2;
      } else {
        merged.add(nonZero[i]);
        i += 1;
      }
    }
    while (merged.length < line.length) {
      merged.add(0);
    }
    return merged;
  }

  void _move(_Direction direction) {
    if (_gameOver) return;
    final before = _grid.map((row) => [...row]).toList();

    switch (direction) {
      case _Direction.left:
        for (var r = 0; r < _size; r++) {
          _grid[r] = _mergeLine(_grid[r]);
        }
        break;
      case _Direction.right:
        for (var r = 0; r < _size; r++) {
          _grid[r] = _mergeLine(_grid[r].reversed.toList()).reversed.toList();
        }
        break;
      case _Direction.up:
        for (var c = 0; c < _size; c++) {
          final col = [for (var r = 0; r < _size; r++) _grid[r][c]];
          final merged = _mergeLine(col);
          for (var r = 0; r < _size; r++) {
            _grid[r][c] = merged[r];
          }
        }
        break;
      case _Direction.down:
        for (var c = 0; c < _size; c++) {
          final col = [for (var r = 0; r < _size; r++) _grid[r][c]];
          final merged = _mergeLine(col.reversed.toList()).reversed.toList();
          for (var r = 0; r < _size; r++) {
            _grid[r][c] = merged[r];
          }
        }
        break;
    }

    final changed = !_gridsEqual(before, _grid);
    if (changed) {
      _spawnTile();
      if (!_canMove()) _gameOver = true;
      _saveBestScoreIfNeeded();
    }
    setState(() {});
  }

  bool _gridsEqual(List<List<int>> a, List<List<int>> b) {
    for (var r = 0; r < _size; r++) {
      for (var c = 0; c < _size; c++) {
        if (a[r][c] != b[r][c]) return false;
      }
    }
    return true;
  }

  bool _canMove() {
    for (var r = 0; r < _size; r++) {
      for (var c = 0; c < _size; c++) {
        if (_grid[r][c] == 0) return true;
        if (c + 1 < _size && _grid[r][c] == _grid[r][c + 1]) return true;
        if (r + 1 < _size && _grid[r][c] == _grid[r + 1][c]) return true;
      }
    }
    return false;
  }

  Color _tileColor(int value) {
    switch (value) {
      case 0:
        return Colors.white;
      case 2:
        return const Color(0xFFF5E9D3);
      case 4:
        return const Color(0xFFF0DDB3);
      case 8:
        return const Color(0xFFF3C98B);
      case 16:
        return const Color(0xFFEDAA5E);
      case 32:
        return const Color(0xFFED9E35); // AppColors.primary
      case 64:
        return const Color(0xFFD9861F);
      case 128:
        return const Color(0xFFC77413);
      case 256:
        return const Color(0xFFB2650F);
      case 512:
        return const Color(0xFF8F510C);
      case 1024:
        return const Color(0xFF0B3D3A);
      default:
        return const Color(0xFF06211F);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('لعبة 2048'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'لعبة جديدة',
            onPressed: _startNewGame,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'اسحب لأي اتجاه لدمج الأرقام المتشابهة، وحاول الوصول إلى 2048.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildScoreCard('النتيجة', _score)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildScoreCard('الأفضل', _bestScore)),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        GestureDetector(
                          onPanEnd: (details) {
                            final v = details.velocity.pixelsPerSecond;
                            if (v.dx.abs() < 80 && v.dy.abs() < 80) return;
                            if (v.dx.abs() > v.dy.abs()) {
                              _move(v.dx > 0 ? _Direction.right : _Direction.left);
                            } else {
                              _move(v.dy > 0 ? _Direction.down : _Direction.up);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: List.generate(_size, (r) {
                                return Expanded(
                                  child: Row(
                                    children: List.generate(_size, (c) {
                                      final value = _grid[r][c];
                                      return Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: _tileColor(value),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            alignment: Alignment.center,
                                            child: value == 0
                                                ? null
                                                : Text(
                                                    '$value',
                                                    style: TextStyle(
                                                      fontSize: value >= 1024
                                                          ? 18
                                                          : 22,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontFamily: 'Cairo',
                                                      color: value <= 4
                                                          ? AppColors.darkText
                                                          : Colors.white,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        if (_won && !_wonBannerDismissed) _buildOverlay(
                          title: '🎉 أحسنت! وصلت 2048',
                          subtitle: 'يمكنك متابعة اللعب لتحقيق رقم أعلى.',
                          buttonLabel: 'متابعة اللعب',
                          onPressed: () =>
                              setState(() => _wonBannerDismissed = true),
                        ),
                        if (_gameOver) _buildOverlay(
                          title: 'انتهت اللعبة',
                          subtitle: 'النتيجة: $_score',
                          buttonLabel: 'إعادة المحاولة',
                          onPressed: _startNewGame,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
