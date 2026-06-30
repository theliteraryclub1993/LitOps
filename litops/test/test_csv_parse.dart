import 'dart:convert';
import 'package:csv/csv.dart';

void main() {
  final csvData = '''USN,Name,Branch,Year
4MC22CS001,"Doe, John",CSE,2
4MC23IS045,Jane Smith,ISE,3
malformed line with no commas
4MC24EC110,Alex,ECE,1
''';

  final stream = Stream.value(csvData)
      .transform(const LineSplitter());

  int rowIndex = 0;
  stream.listen((line) {
    rowIndex++;
    try {
      final rows = const CsvToListConverter().convert(line);
      if (rows.isEmpty) {
        print('Row \$rowIndex is empty');
        return;
      }
      final row = rows.first;
      print('Row \$rowIndex parsed successfully: \$row');
    } catch (e) {
      print('Row \$rowIndex failed to parse: \$e');
    }
  });
}
