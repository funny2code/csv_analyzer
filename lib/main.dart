import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/gestures.dart';

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => { 
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<List<dynamic>> csvData = [];
  List<String> headers = [];

  Future<void> _pickAndReadCsvFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final String? fileContent = utf8.decode(result.files.single.bytes!, allowMalformed: true);
        List<List<dynamic>> csvTable =
            const CsvToListConverter().convert(fileContent);

        setState(() {
          headers = List<String>.from(csvTable[0]); // First row as headers
          csvData = csvTable.sublist(1); // Sublist excluding headers
        });
      }
      else {
        // Handle case when no file is selected
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No file selected')),
        );
      }
    } catch (e) {
      print('Error reading CSV file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Importing CSV Files into Firestore"),
      ),
      body: ScrollConfiguration(
        behavior: MyCustomScrollBehavior(),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _pickAndReadCsvFile,
              child: Text('Pick and Read CSV'),
            ),
            Flexible(
               child: (headers.isEmpty || csvData.isEmpty)
                  ? Center(child: Text('No data available'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: headers.map((header) {
                          return DataColumn(label: Text(header));
                        }).toList(),
                        rows: csvData.map((row) {
                          return DataRow(cells: row.map((cell) {
                            return DataCell(Text(cell.toString()));
                          }).toList());
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      )
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: MyHomePage(),
  ));
}
