// 极简 CSV 解析 / 生成工具（支持引号包裹字段、字段内换行）
library;

/// 解析 CSV 文本为二维数组
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;

  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  for (var i = 0; i < normalized.length; i++) {
    final ch = normalized[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < normalized.length && normalized[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',') {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(ch);
    }
  }

  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }

  return rows.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
}

/// 生成 CSV 文本（自动为含逗号/引号/换行的字段加引号）
String toCsv(List<List<String>> rows) {
  String escape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  return rows.map((r) => r.map(escape).join(',')).join('\r\n');
}
