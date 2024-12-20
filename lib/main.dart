import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:csv/csv.dart';

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<List<dynamic>> _data = [];

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
          _data = csvTable;
        });
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
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickAndReadCsvFile,
            child: Text('Importing CSV Files into Firestore'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _data.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_data[index].join(", ")),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(home: MyHomePage()));
}
