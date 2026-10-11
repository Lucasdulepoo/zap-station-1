/// Horário curto para a lista de conversas: HH:mm hoje, "Ontem", ou dd/MM.
String formatActivityTime(DateTime time, DateTime now) {
  final t = time.toLocal();
  final n = now.toLocal();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final diffDays = today.difference(day).inDays;

  String two(int v) => v.toString().padLeft(2, '0');

  if (diffDays <= 0) return '${two(t.hour)}:${two(t.minute)}';
  if (diffDays == 1) return 'Ontem';
  return '${two(t.day)}/${two(t.month)}';
}
