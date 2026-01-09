import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

void main() async {
  print('Connecting to Termux via SSH...');
  
  try {
    final socket = await SSHSocket.connect('127.0.0.1', 8022);
    
    final client = SSHClient(
      socket,
      username: 'u0_a1002',
      onPasswordRequest: () => '1234',
    );
    
    print('Connected! Executing configuration commands...');
    
    // Create .termux directory and config file
    var result = await client.run('mkdir -p ~/.termux');
    print('mkdir: ${result.toString()}');
    
    result = await client.run('echo "allow-external-apps=true" >> ~/.termux/termux.properties');
    print('echo: ${result.toString()}');
    
    result = await client.run('cat ~/.termux/termux.properties');
    print('Config file content: ${result.toString()}');
    
    result = await client.run('termux-reload-settings');
    print('reload: ${result.toString()}');
    
    print('Configuration completed!');
    client.close();
    
  } catch (e) {
    print('SSH Error: $e');
    
    // Try to get the actual username first
    print('Attempting to get Termux username...');
  }
}
