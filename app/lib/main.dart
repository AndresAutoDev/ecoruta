// Autores: Andrés Gómez y Daniel Rodríguez - Proyecto EcoRuta
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // requiere google-services.json (no versionado)
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true); // modo offline
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously(); // JWT gestionado por Firebase Auth
  }
  runApp(const EcoRuta());
}

class EcoRuta extends StatelessWidget {
  const EcoRuta({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'EcoRuta',
        theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
        home: const ReportScreen(),
      );
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  File? _photo;
  String _label = 'Sin clasificar';
  double _conf = 0;
  bool _busy = false;

  /// Captura foto y clasifica el residuo EN el dispositivo (ML Kit, sin costo de servidor).
  Future<void> _capture() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1024);
    if (x == null) return;
    final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
    final labels = await labeler.processImage(InputImage.fromFilePath(x.path));
    await labeler.close();
    setState(() {
      _photo = File(x.path);
      if (labels.isNotEmpty) {
        _label = labels.first.label;
        _conf = labels.first.confidence;
      }
    });
  }

  /// Guarda el reporte; con Firestore offline se sincroniza al volver la conexión.
  Future<void> _send() async {
    if (_photo == null) return;
    setState(() => _busy = true);
    final pos = await Geolocator.getCurrentPosition();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref('reports/$uid/$id.jpg');
    await FirebaseFirestore.instance.collection('reports').doc(id).set({
      'uid': uid,
      'label': _label,
      'confidence': _conf,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    ref.putFile(_photo!); // se encola si no hay red
    setState(() => _busy = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte enviado')));
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('EcoRuta ♻️')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            if (_photo != null) Expanded(child: Image.file(_photo!)),
            Text('$_label (${(_conf * 100).toStringAsFixed(0)}%)', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _capture, icon: const Icon(Icons.camera_alt), label: const Text('Fotografiar residuo')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _busy ? null : _send, child: const Text('Enviar reporte')),
          ]),
        ),
      );
}
