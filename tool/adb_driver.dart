
import 'dart:io';
import 'dart:async';

Future<void> adb(List<String> args) async {
  final result = await Process.run('adb', args, runInShell: true);
  if (result.exitCode != 0) {
    print('ADB Error: ${result.stderr}');
  }
}

Future<void> inputKey(int keycode) async {
  await adb(['shell', 'input', 'keyevent', keycode.toString()]);
  await Future.delayed(Duration(milliseconds: 100)); // Delay for stability
}

Future<void> inputText(String text) async {
  // Split text to be safe and handle special chars if needed, 
  // but adb shell "input text '...'" is mostly robust if we escape single quotes.
  // We will iterate chars to be super safe.
  
  for (int i = 0; i < text.length; i++) {
    String char = text[i];
    if (char == ' ') {
      await inputKey(62); // SPACE
    } else if (char == '>') {
      // Escape > for shell
      await adb(['shell', 'input', 'text', '\\>']); 
    } else if (char == '"') {
      await adb(['shell', 'input', 'text', '\\"']);
    } else if (char == "'") {
       await adb(['shell', 'input', 'text', "\\'"]);
    } else {
      await adb(['shell', 'input', 'text', char]);
    }
    await Future.delayed(Duration(milliseconds: 50));
  }
}

void main() async {
  print('Starting Operation Dart Driver...');
  
  // 1. Reset Termux
  print('Resetting Termux...');
  await adb(['shell', 'am', 'force-stop', 'com.termux']);
  await adb(['shell', 'monkey', '-p', 'com.termux', '-c', 'android.intent.category.LAUNCHER', '1']);
  await Future.delayed(Duration(seconds: 3));
  
  // 2. Clear Screen / Line (Ctrl+C effectively or just tons of backspace?)
  // Let's just assume fresh session or clear line.
  // Ctrl+C is KeyCode 31 with META_CTRL_ON... hard via input.
  // Let's hold delete.
  await inputKey(123); // MOVE_END
  for(int i=0; i<50; i++) {
      await adb(['shell', 'input', 'keyevent', '67']); // DEL
  }

  // 3. Ensure Home and Directory
  print('Creating directory...');
  await inputText('cd');
  await inputKey(66); // ENTER
  await Future.delayed(Duration(seconds: 1));
  
  await inputText('mkdir -p .termux');
  await inputKey(66); // ENTER
  await Future.delayed(Duration(seconds: 1));

  // 4. Write Config
  print('Writing config...');
  // Use > to overwrite, ensuring clean state. 
  // Path: .termux/termux.properties (relative to home)
  await inputText('echo "allow-external-apps=true" > .termux/termux.properties');
  await inputKey(66); // ENTER
  await Future.delayed(Duration(seconds: 1));

  // 5. Reload
  print('Reloading settings...');
  await inputText('termux-reload-settings');
  await inputKey(66); // ENTER
  await Future.delayed(Duration(seconds: 2));
  
  print('Done. Termux configuration should be applied.');
}
