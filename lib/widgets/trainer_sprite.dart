// lib/widgets/trainer_sprite.dart
//
// Os treinadores BW (lib/services/trainers.dart): a frente animada (os
// quadros da tira passam em loop, com uma pausa no primeiro), as costas
// lançando a Poké Ball, o rosto para a foto de perfil e a escolha do seu
// treinador. Igual ao site (web-site/src/components/Trainer.jsx).

import 'dart:math';

import 'package:flutter/material.dart' hide Text;

import '../services/trainers.dart';
import '../services/user_data.dart';
import '../utils/site_ui.dart';
import 'package:pocket_dex/i18n/text.dart';

/// Um quadro de uma tira: [frame] de [frames], cada um [w] × [h] px, mostrado com [scale] px por pixel.
Widget _frameOf(String asset, {required int frame, required int frames, required int w, required int h, required double scale, bool flip = false}) {
  final image = Image.asset(asset,
      width: w * frames * scale, height: h * scale, fit: BoxFit.fill, filterQuality: FilterQuality.none, gaplessPlayback: true);
  final cropped = SizedBox(
    width: w * scale,
    height: h * scale,
    child: ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: double.infinity,
        child: Transform.translate(offset: Offset(-frame * w * scale, 0), child: image),
      ),
    ),
  );
  return flip ? Transform.flip(flipX: true, child: cropped) : cropped;
}

/// A frente animada, apoiada embaixo numa caixa de [box] px (um quadro de 96 px cabe nela).
class TrainerSprite extends StatefulWidget {
  final Trainer trainer;
  final double box;
  final bool flip, still;
  const TrainerSprite(this.trainer, {super.key, this.box = 96, this.flip = false, this.still = false});

  @override
  State<TrainerSprite> createState() => _TrainerSpriteState();
}

class _TrainerSpriteState extends State<TrainerSprite> with SingleTickerProviderStateMixin {
  // Cada quadro 90 ms, e uma pausa de 900 ms no primeiro.
  late final AnimationController _clock = AnimationController(vsync: this, duration: _cycle);

  Duration get _cycle => _idle ? const Duration(milliseconds: 2400) : Duration(milliseconds: widget.trainer.frames * 90 + 900);

  @override
  void initState() {
    super.initState();
    if (_moving || _idle) _clock.repeat();
  }

  bool get _moving => !widget.still && widget.trainer.frames > 1;

  /// Sem quadros de animação (sprites parados): respira de leve, apoiado nos pés. Igual ao site (trainer-idle).
  bool get _idle => !widget.still && widget.trainer.frames <= 1;

  @override
  void didUpdateWidget(TrainerSprite old) {
    super.didUpdateWidget(old);
    if (old.trainer.id != widget.trainer.id || old.still != widget.still) {
      _clock.duration = _cycle;
      if (_moving || _idle) {
        _clock.repeat();
      } else {
        _clock.stop();
      }
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trainer;
    final k = widget.box / 96 * t.scale;
    return SizedBox.square(
      dimension: widget.box,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final ms = _clock.value * _cycle.inMilliseconds;
            final frame = !_moving || ms < 900 ? 0 : (1 + (ms - 900) ~/ 90).clamp(0, t.frames - 1);
            final sprite = _frameOf(t.front, frame: frame, frames: t.frames, w: t.size, h: t.size, scale: k, flip: widget.flip);
            if (!_idle) return sprite;
            final breath = (1 - cos(_clock.value * 2 * pi)) / 2;
            return Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(1 + 0.012 * breath, 1 + 0.03 * breath, 1),
              child: sprite,
            );
          },
        ),
      ),
    );
  }
}

/// As costas lançando a Poké Ball ([frame] de 0 a 4), com [height] px de altura.
/// Sem costas: a frente virada para a direita.
class TrainerBack extends StatelessWidget {
  final Trainer trainer;
  final int frame;
  final double height;
  const TrainerBack(this.trainer, {super.key, this.frame = 0, this.height = 140});

  @override
  Widget build(BuildContext context) {
    final b = trainer.back;
    if (b == null) return TrainerSprite(trainer, box: height * 0.8, flip: true);
    return _frameOf(trainer.backPath, frame: frame.clamp(0, b.frames - 1), frames: b.frames, w: b.width, h: b.height, scale: height / b.height);
  }
}

/// O rosto do treinador para a foto de perfil (o primeiro quadro, mais perto).
class TrainerFace extends StatelessWidget {
  final Trainer trainer;
  final double size;
  const TrainerFace(this.trainer, {super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final side = size * 1.9;
    return SizedBox.square(
      dimension: size,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: side,
          maxHeight: side,
          alignment: const Alignment(0, -1.1),
          child: _frameOf(trainer.front, frame: 0, frames: trainer.frames, w: trainer.size, h: trainer.size, scale: side / trainer.size),
        ),
      ),
    );
  }
}

/// Escolher o seu treinador (e, se quiser, usar como foto de perfil).
class TrainerPicker extends StatefulWidget {
  const TrainerPicker({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => const TrainerPicker(),
      );

  @override
  State<TrainerPicker> createState() => _TrainerPickerState();
}

class _TrainerPickerState extends State<TrainerPicker> {
  late String _pick = UserData.instance.trainer;
  String _query = '';

  @override
  void initState() {
    super.initState();
    Trainers.load().then((_) => mounted ? setState(() {}) : null);
  }

  void _save({bool photo = false}) {
    final index = Trainers.list.indexWhere((t) => t.id == _pick);
    if (index < 0) return;
    UserData.instance.update({'trainer': _pick, if (photo) 'avatar': Trainers.avatarBase + index});
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final q = _query.trim().toLowerCase();
    final shown = [for (final t in Trainers.list) if (q.isEmpty || t.name.toLowerCase().contains(q) || t.title.toLowerCase().contains(q)) t];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Escolha seu treinador', style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Ele aparece na batalha lançando a Poké Ball e pode ser a sua foto de perfil.',
                textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('trainer-search'),
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: tr('Buscar treinador'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.8),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final t = shown[i];
                  return InkWell(
                    key: ValueKey('trainer-${t.id}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _pick = t.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _pick == t.id ? const Color(0x26EF4444) : c.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _pick == t.id ? const Color(0xFFEF4444) : Colors.transparent, width: 2),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        children: [
                          Expanded(child: LayoutBuilder(builder: (context, box) => TrainerSprite(t, box: box.biggest.shortestSide))),
                          Text(t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w800)),
                          Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => _save(photo: true), child: const Text('Escolher e usar como foto'))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton(onPressed: _save, child: const Text('Escolher'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
