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
    
    // Check permissions
    var result = await client.run('stat -c "%a %n" ~/.termux/termux.properties');
    print('Current Mode: ${String.fromCharCodes(result).trim()}');
    
    // Force Overwrite with clean content
    print('Overwriting config...');
    await client.run('printf "allow-external-apps=true\\n" > ~/.termux/termux.properties');
    
    // chmod 600
    await client.run('chmod 600 ~/.termux/termux.properties');
    
    // Verify content
    result = await client.run('cat ~/.termux/termux.properties');
    String content = String.fromCharCodes(result);
    print('New Content: [${content.trim()}]'); // Brackets to see spaces
    
    // Reload
    print('Reloading settings...');
    await client.run('termux-reload-settings');
    
    client.close();
    print('Done!');
    
  } catch (e) {
    print('SSH Error: $e');
  }
}
