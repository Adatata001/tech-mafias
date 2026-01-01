// scripts/upload_existing_phases_auth.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:techmafias/phases/backend.dart';
import 'package:techmafias/phases/frontend.dart';
import 'package:techmafias/phases/graphics_design.dart';
import 'package:techmafias/phases/product_design.dart';
import 'package:techmafias/phases/social_media_management.dart';
import 'package:techmafias/phases/project_management.dart';
import 'package:techmafias/phases/creative_director.dart';

Future<void> main() async {
  print('🚀 Uploading existing phases to Firestore...\n');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyB3GQsgOAssn2UG9tKLTR27W8NIhPNJUWs',
        appId: '1:1023291833256:web:837434d109812b09fa3b9d',
        messagingSenderId: '1023291833256',
        projectId: 'tech-mafias',
        authDomain: 'tech-mafias.firebaseapp.com',
        storageBucket: 'tech-mafias.firebasestorage.app',
      ),
    );
    
    print('✅ Firebase initialized\n');
    
    // SIGN IN WITH CREDENTIALS
    print('🔐 Signing in with noraokorodudu@gmail.com...');
    final auth = FirebaseAuth.instance;
    
    try {
      // Try to sign in
      final userCredential = await auth.signInWithEmailAndPassword(
        email: 'noraokorodudu@gmail.com',
        password: '123456',
      );
      
      print('✅ Signed in successfully!');
      print('   User: ${userCredential.user?.email}');
      print('   UID: ${userCredential.user?.uid}\n');
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('⚠️  User not found, creating account...');
        
        // Create the user
        final userCredential = await auth.createUserWithEmailAndPassword(
          email: 'noraokorodudu@gmail.com',
          password: '123456',
        );
        
        print('✅ Account created and signed in!');
        print('   User: ${userCredential.user?.email}');
        print('   UID: ${userCredential.user?.uid}\n');
        
      } else if (e.code == 'wrong-password') {
        print('❌ Wrong password for noraokorodudu@gmail.com');
        print('💡 Please check the password or reset it in Firebase Console');
        exit(1);
      } else {
        print('❌ Authentication error: ${e.code} - ${e.message}');
        exit(1);
      }
    } catch (e) {
      print('❌ Unexpected auth error: $e');
      exit(1);
    }
    
    final db = FirebaseFirestore.instance;
    
    // Upload each phase exactly as it exists
    print('📤 Starting upload process...\n');
    await uploadPhase(db, 'backend-dev', backendRoadmap);
    await uploadPhase(db, 'frontend-dev', frontendRoadmap);
    await uploadPhase(db, 'graphic-designer', graphicsDesignRoadmap);
    await uploadPhase(db, 'product-designer', productDesignRoadmap);
    await uploadPhase(db, 'social-media', socialMediaManagementRoadmap);
    await uploadPhase(db, 'project-manager', projectManagementRoadmap);
    await uploadPhase(db, 'creative-director', creativeDirectorRoadmap);
    
    print('\n🎉 All phases uploaded successfully!');
    print('✅ Dashboard should now work!');
    
    // Sign out after upload
    await auth.signOut();
    print('🔒 Signed out');
    
  } catch (e) {
    print('\n❌ Error: $e');
    print('\n🔧 Debug info:');
    print('• Make sure the user noraokorodudu@gmail.com exists in Firebase Authentication');
    print('• Make sure password is correct');
    print('• Check Firestore rules allow authenticated writes');
  }
  
  exit(0);
}

Future<void> uploadPhase(
  FirebaseFirestore db, 
  String role, 
  List<dynamic> phaseData,
) async {
  print('📤 Uploading: $role');
  
  try {
    // Check if user is still signed in
    if (FirebaseAuth.instance.currentUser == null) {
      print('   ⚠️  Not signed in, attempting re-authentication...');
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'noraokorodudu@gmail.com',
        password: '123456',
      );
    }
    
    // Convert your phase data to a format Firestore can store
    final tasks = phaseData.map((item) {
      // If it's already a Map, use it as-is
      if (item is Map) {
        return {
          ...item,
          'role': role,
          'completed': false,
          'votes': 0,
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
        };
      }
      
      // If it's a Roadmap object, convert it
      return {
        'id': item.id,
        'role': role,
        'week': item.week,
        'day': item.day,
        'title': item.title,
        'description': item.description,
        'completed': false,
        'votes': 0,
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
      };
    }).toList();
    
    // Group tasks by week
    final Map<int, List<dynamic>> weeksMap = {};
    for (final task in tasks) {
      final week = task['week'] ?? 1;
      weeksMap.putIfAbsent(week, () => []);
      weeksMap[week]!.add(task);
    }
    
    // Create weeks array
    final weeks = weeksMap.entries.map((entry) {
      return {
        'weekNumber': entry.key,
        'tasks': entry.value,
      };
    }).toList();
    
    // Sort by week
    weeks.sort((a, b) => (a['weekNumber'] as int).compareTo(b['weekNumber'] as int));
    
    // Create the roadmap document
    final roadmapDoc = {
      'role': role,
      'title': _getTitle(role),
      'description': _getDescription(role),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'totalWeeks': weeks.length,
      'totalTasks': tasks.length,
      'createdBy': FirebaseAuth.instance.currentUser?.uid,
      'createdByEmail': FirebaseAuth.instance.currentUser?.email,
      'weeks': weeks,
    };
    
    // Upload to Firestore
    await db.collection('roadmaps').doc(role).set(roadmapDoc);
    
    print('   ✅ Uploaded ${tasks.length} tasks in ${weeks.length} weeks');
    
  } catch (e) {
    print('   ❌ Failed: $e');
    print('   💡 Check if user has permission to write to Firestore');
  }
}

String _getTitle(String role) {
  final titles = {
    'backend-dev': 'Backend Developer Roadmap',
    'frontend-dev': 'Frontend Developer Roadmap',
    'graphic-designer': 'Graphic Designer Roadmap',
    'product-designer': 'Product Designer Roadmap',
    'social-media': 'Social Media Manager Roadmap',
    'project-manager': 'Project Manager Roadmap',
    'creative-director': 'Creative Director Roadmap',
  };
  return titles[role] ?? '$role Roadmap';
}

String _getDescription(String role) {
  final descriptions = {
    'backend-dev': 'Complete backend development learning path',
    'frontend-dev': 'Complete frontend development learning path',
    'graphic-designer': 'Complete graphic design learning path',
    'product-designer': 'Complete product design learning path',
    'social-media': 'Complete social media management learning path',
    'project-manager': 'Complete project management learning path',
    'creative-director': 'Complete creative direction learning path',
  };
  return descriptions[role] ?? 'Learning roadmap for $role';
}