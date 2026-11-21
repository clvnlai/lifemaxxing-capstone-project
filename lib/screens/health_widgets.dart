import 'package:flutter/material.dart';

const hBg = Color(0xFFF4F5F7);
const hCard = Color(0xFFFFFFFF);
const hBorder = Color(0xFFE6E9EF);
const hMuted = Color(0xFF6B7280);
const hInk = Color(0xFF111418);
const hNavy = Color(0xFF14213D);
const hSleep = Color(0xFF14213D);
const hExercise = Color(0xFF5B6B85);
const hMood = Color(0xFF9AA3B2);
const hStreak = Color(0xFF111418);

class HCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const HCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: hCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hBorder),
      ),
      child: child,
    );
  }
}

class HProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const HProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0).toDouble(),
        minHeight: height,
        backgroundColor: color.withAlpha(45),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

class HRing extends StatelessWidget {
  final double progress;
  final Color color;
  final IconData icon;
  final String value;
  final String label;
  const HRing({
    super.key,
    required this.progress,
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0).toDouble(),
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  backgroundColor: color.withAlpha(45),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Icon(icon, color: color, size: 26),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: hMuted, fontSize: 12)),
      ],
    );
  }
}

class HMetricTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String sub;
  final double progress;
  final Color color;
  const HMetricTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.sub,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return HCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    style: const TextStyle(color: hMuted, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: hMuted, fontSize: 11)),
          const SizedBox(height: 10),
          HProgressBar(value: progress, color: color),
        ],
      ),
    );
  }
}

class HBarRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String avg;
  final String streak;
  final Color color;
  final List<double?> values;
  final List<String> labels;
  final double goal;
  final double maxValue;

  const HBarRow({
    super.key,
    required this.icon,
    required this.title,
    required this.avg,
    required this.streak,
    required this.color,
    required this.values,
    required this.labels,
    required this.goal,
    required this.maxValue,
  });

  static const _barArea = 70.0;

  double _height(double? v) {
    if (v == null || v <= 0) return 4;
    return (v / maxValue * _barArea).clamp(4.0, _barArea).toDouble();
  }

  Color _color(double? v) {
    if (v == null || v <= 0) return hBorder;
    return v >= goal ? color : color.withAlpha(110);
  }

  @override
  Widget build(BuildContext context) {
    final slim = values.length > 7;
    return HCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(avg,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(streak,
                    style: const TextStyle(color: hMuted, fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: SizedBox(
              height: _barArea + 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: slim ? double.infinity : 14,
                            height: _height(values[i]),
                            margin:
                                EdgeInsets.symmetric(horizontal: slim ? 1 : 0),
                            decoration: BoxDecoration(
                              color: _color(values[i]),
                              borderRadius:
                                  BorderRadius.circular(slim ? 2 : 7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 12,
                            child: Text(
                              slim ? '' : labels[i],
                              style: const TextStyle(
                                  color: hMuted, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}