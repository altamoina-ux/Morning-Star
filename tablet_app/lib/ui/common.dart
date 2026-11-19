import 'package:material_ui/material_ui.dart';

const accent = Color(0xff67e0cf);
const muted = Color(0xffa5b5c8);
const surface = Color(0xff142338);

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Material(
    color: surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xff27394e)),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff302e25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xffffd68a)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.6))),
          ?action,
        ],
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key, this.action});
  final String title;
  final String subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: muted)),
          ],
        ),
        ?action,
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.good = false});
  final String text;
  final bool good;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: (good ? accent : muted).withValues(alpha: .12),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: TextStyle(color: good ? accent : muted, fontSize: 13),
    ),
  );
}

String timeLabel(dynamic raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (date == null) return '时间未知';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
}

String directionLabel(dynamic value) => switch (value) {
  'left' => '左侧',
  'right' => '右侧',
  'front' => '前方',
  _ => '方位未知',
};
const objectNames = <String, String>{
  'person': '行人',
  'bicycle': '自行车',
  'car': '汽车',
  'motorcycle': '摩托车',
  'bus': '公交车',
  'truck': '卡车',
  'train': '火车',
  'traffic light': '交通灯',
  'fire hydrant': '消防栓',
  'stop sign': '停车标志',
  'bench': '长椅',
  'cat': '猫',
  'dog': '狗',
  'bird': '鸟',
  'horse': '马',
  'backpack': '背包',
  'umbrella': '雨伞',
  'handbag': '手提包',
  'suitcase': '行李箱',
  'chair': '椅子',
  'couch': '沙发',
  'bed': '床',
  'dining table': '餐桌',
  'potted plant': '盆栽',
  'tv': '电视',
  'laptop': '笔记本电脑',
  'cell phone': '手机',
  'bottle': '瓶子',
  'cup': '杯子',
  'book': '书本',
  'clock': '时钟',
  'toilet': '马桶',
  'sink': '水槽',
};
String objectLabel(dynamic name) =>
    objectNames[name] ?? name?.toString() ?? '未知物体';
