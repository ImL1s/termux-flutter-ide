import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

void main() async {
  print('Connecting to Termux via SSH...');
  
  try {
    final socket = await SSHSocket.connect('127.0.0.1', 8022);
    
    final client = SSHClient(
      socket,
      username: 'u0_a436',
      onPasswordRequest: () => '1234',
    );
    
    print('Connected!');
    
    // Check config file
    var result = await client.run('cat ~/.termux/termux.properties');
    String content = String.fromCharCodes(result);
    print('Config file content: $content');
    
    // Check if setting is present
    if (content.contains('allow-external-apps=true')) {
      print('✅ Setting is correctly configured!');
    } else {
      print('❌ Setting not found, adding it...');
      await client.run('mkdir -p ~/.termux');
      await client.run('echo "allow-external-apps=true" > ~/.termux/termux.properties');
      result = await client.run('cat ~/.termux/termux.properties');
      print('New content: ${String.fromCharCodes(result)}');
    }
    
    // Verify file permissions
    result = await client.run('ls -la ~/.termux/');
    print('Directory listing: ${String.fromCharCodes(result)}');
    
    client.close();
    print('Done!');
    
  } catch (e) {
    print('SSH Error: $e');
  }
}
