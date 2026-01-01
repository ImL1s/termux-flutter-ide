import 'dart:convert';
import 'package:http/http.dart' as http;

class PubPackage {
  final String name;
  final String version;
  final String description;

  PubPackage({
    required this.name,
    required this.version,
    required this.description,
  });

  factory PubPackage.fromJson(Map<String, dynamic> json) {
    return PubPackage(
      name: json['name'] ?? '',
      version: json['version'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class PubDevService {
  static const String _baseUrl = 'https://pub.dev/api';

  Future<List<String>> searchPackages(String query) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/search?q=$query'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final packages = data['packages'] as List;
        return packages.map((p) => p['package'] as String).toList();
      }
    } catch (e) {
      print('PubDevService: Search error: $e');
    }
    return [];
  }

  Future<PubPackage?> getPackageDetails(String name) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/packages/$name'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latest = data['latest']['pubspec'];
        return PubPackage.fromJson(latest);
      }
    } catch (e) {
      print('PubDevService: Detail error: $e');
    }
    return null;
  }
}
