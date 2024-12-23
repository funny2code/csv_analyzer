import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

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
  Map<String, dynamic> documentFields = {};
  List<String> fields = ["X31","品目K","品目C","ローレベルC","略称カナ","品目名1","品目名2","記号型番","科目C","基準在庫数","最低在庫数",
    "標準単位","標準単価","X19","税金K","X22","調達K","X12","支給K","製造ロット数","製造リードタイム","図面番号","歩留数",
    "場所C_ﾛｹｰｼｮﾝ","略号","科目C2","X91","分類C1","X92","分類C2","X93","分類C3","員数単位","員数","X09","在備K","X01","管理K",
    "単位重量","X06","計算K","比重","加工時間_回","X31B","代替品目K","代替品目C","資材単価1","資材単価2","資材単価3",
    "資材単価4","資材単価5","資材単価6","資材単価7","資材単価8","資材単価9","資材単価10","資材単価11","資材単価12",
    "資材単価13","資材単価14","資材単価15","員数計算F","機械C","X39","検査K","期間算定値","注文書不要F","取引先C","品目名3",
    "品目名4","新規登録日","最終変更日","発注先C","発注単価","発注ロット数","発注リードタイム","イメージラベル",
    "イメージNO","計画製番カウンター","出荷製番カウンター","X31C","金型品目K","金型C","寸法1","寸法2","寸法3","寸法4",
    "有効開始日","有効終了日","X48","留意K","X94","分類C4","X95","分類C5","X96","分類C6","中止番号","出力日時分","科目名","税金区分",
    "調達区分","支給区分","在備区分","管理区分","計算区分","資材区分","代替資材区分","留意区分","代替資材名1","代替資材名2",
    "バーコード場所C","バーコード品目KC","取引先名","廃止F","廃止","製造手配区分名"];
  double? importProgress;
  final int itemsPerPage = 10;
  int currentPage = 0;
  bool isLoading = false;
  List<DocumentSnapshot> documents = [];
  DocumentSnapshot? lastDocument;

  @override
  void initState() {
    super.initState();
    _fetchPage(clear: true);
  }

  Future<void> insertDataToFirestore(List<List<dynamic>> fieldValues) async {
    final CollectionReference collection = FirebaseFirestore.instance.collection('materials');

    print("insertDataToFirestore: fieldValues.length = ${fieldValues.length}");
    for (int index = 0; index < fieldValues.length; index++) {
      var row = fieldValues[index];
      Map<String, dynamic> documentData = {};
      for (int i = 0; i < fields.length; i++) {
        documentData[fields[i]] = row[i];
      }
      await collection.add(documentData);

      // Update import progress
      setState(() {
        importProgress = (index + 1) / fieldValues.length * 100;
      });
    }
  }

  Future<void> _pickAndReadCsvFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final String? fileContent = utf8.decode(result.files.single.bytes!, allowMalformed: true);
        List<List<dynamic>> csvTable = const CsvToListConverter().convert(fileContent);

        setState(() {
          importProgress = 0;
        });
        
        await insertDataToFirestore(csvTable.sublist(1));
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
      print('Error reading CSV file');
      // Handle the error as needed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading CSV file')),
      );
    }
  }

  Future<void> _fetchPage({required bool clear}) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
      if (clear) {
        documents.clear();
        lastDocument = null;
      }
    });

    Query query = FirebaseFirestore.instance
        .collection('materials')
        .limit(itemsPerPage);

    if (lastDocument != null && !clear) {
      query = query.startAfterDocument(lastDocument!);
    }

    QuerySnapshot snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      lastDocument = snapshot.docs.last;
      setState(() {
        documents.addAll(snapshot.docs);
        if (clear) {
          currentPage = 1;
        } else {
          currentPage += 1;
        }
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<List<DocumentSnapshot>> fetchData() async {
    final firestore = FirebaseFirestore.instance;
    QuerySnapshot snapshot = await firestore.collection('items').get();
    return snapshot.docs;
  }

  Future<void> _previousPage() async {
    if (currentPage <= 1 || isLoading) return;

    setState(() {
      isLoading = true;
      currentPage -= 2; // Since `_fetchPage` automatically moves to next page
    });

    _fetchPage(clear: true);
  }

  Future<void> _nextPage() async {
    if (isLoading) return;
    await _fetchPage(clear: false);
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
            Expanded( child: _buildDataGrid()),
            if (importProgress != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Import Progress: ${importProgress!.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            if (isLoading) CircularProgressIndicator(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _previousPage,
                  child: Text('Previous'),
                ),
                Text("Page $currentPage"),
                ElevatedButton(
                  onPressed: _nextPage,
                  child: Text('Next'),
                ),
              ],
            ),
            ElevatedButton(onPressed: _pickAndReadCsvFile, child: Text("Import CSV")),
          ],
        ),
      )
        
    );
  }
  Widget _buildDataGrid() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: fields.map((field) => DataColumn(label: Text(field))).toList(),
          rows: documents.map((document) {
            var data = document.data() as Map<String, dynamic>;
            return DataRow(
              cells: fields.map((field) => DataCell(Text(data[field]?.toString() ?? ''))).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MaterialApp(
    home: MyHomePage(),
  ));
}
