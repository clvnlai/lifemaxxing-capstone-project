import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DataService {
  final String collection;
  DataService(this.collection);

  CollectionReference<Map<String, dynamic>> get _col {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(collection);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> stream() =>
      _col.orderBy('createdAt', descending: true).snapshots();

  Future<void> add(Map<String, dynamic> data) =>
      _col.add({...data, 'createdAt': FieldValue.serverTimestamp()});

  Future<void> update(String id, Map<String, dynamic> data) =>
      _col.doc(id).update(data);

  Future<void> delete(String id) => _col.doc(id).delete();
}