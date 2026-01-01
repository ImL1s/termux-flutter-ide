import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vm_service/vm_service.dart' as vm;
import 'package:termux_flutter_ide/run/vm_service_manager.dart';
import 'package:termux_flutter_ide/run/breakpoint_service.dart';

class DebugPanelWidget extends ConsumerWidget {
  const DebugPanelWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: const Color(0xFF181825),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            return const _TabletDebugPanel();
          } else {
            return const _MobileDebugPanel();
          }
        },
      ),
    );
  }
}

class _MobileDebugPanel extends StatelessWidget {
  const _MobileDebugPanel();

  @override
  Widget build(BuildContext context) {
    // Mobile: Compact vertical layout
    // In future, this could be a bottom sheet content.
    // For now, keep it similar to previous vertical stack but maybe more compact?
    // User plan said: "Bottom Sheet / Drawer".
    // Since this widget is likely placed *inside* a drawer or panel effectively already in the current UI structure (Drawer),
    // we keep the vertical column but ensure it fits narrowly.
    // The "Floating Toolbar" part needs to be in CodeEditorWidget or a parent Stack,
    // but here we define the content of the "Panel" itself.

    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // On Mobile, Controls might be floating, but if we are IN the panel (Drawer),
        // we might still want them or hide them?
        // Plan says: "Floating Toolbar: ... in editor bottom-center".
        // So this Panel (Bottom Sheet/Drawer) mainly holds Data.
        // Let's keep controls here for now as a fallback or duplication until Floating is implemented.
        DebugControls(),
        Divider(height: 1, color: Color(0xFF313244)),
        _Header(title: 'VARIABLES'),
        Expanded(flex: 2, child: _VariablesList()),
        Divider(height: 1, color: Color(0xFF313244)),
        _Header(title: 'CALL STACK'),
        Expanded(flex: 1, child: _CallStackList()),
        Divider(height: 1, color: Color(0xFF313244)),
        _Header(title: 'BREAKPOINTS'),
        Expanded(flex: 1, child: _BreakpointsList()),
        Divider(height: 1, color: Color(0xFF313244)),
        _ExpressionInput(),
      ],
    );
  }
}

class _TabletDebugPanel extends StatelessWidget {
  const _TabletDebugPanel();

  @override
  Widget build(BuildContext context) {
    // Tablet: Persistent right panel style with Flex layout
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DebugControls(), // Toolbar at top
        Divider(height: 1, color: Color(0xFF313244)),
        _Header(title: 'VARIABLES'),
        Expanded(flex: 3, child: _VariablesList()),
        Divider(height: 1, color: Color(0xFF313244)),
        _Header(title: 'CALL STACK'),
        Expanded(flex: 2, child: _CallStackList()),
        Divider(height: 1, color: Color(0xFF313244)),
        _Header(title: 'BREAKPOINTS'),
        Expanded(flex: 2, child: _BreakpointsList()),
        Divider(height: 1, color: Color(0xFF313244)),
        _ExpressionInput(),
      ],
    );
  }
}

class DebugControls extends ConsumerWidget {
  const DebugControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vmManager = ref.watch(vmServiceManagerProvider);
    final statusAsync = ref.watch(vmServiceStatusProvider);
    final status = statusAsync.asData?.value ?? VMServiceStatus.disconnected;

    final isPaused = status == VMServiceStatus.paused;
    final isConnected = status == VMServiceStatus.connected || isPaused;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Resume / Pause
          IconButton(
            icon: Icon(
              isPaused ? Icons.play_arrow : Icons.pause,
              color: isPaused ? Colors.greenAccent : Colors.orangeAccent,
            ),
            tooltip: isPaused ? 'Resume' : 'Pause',
            onPressed: isConnected
                ? () {
                    if (isPaused) {
                      vmManager.resume();
                    } else {
                      vmManager.pause();
                    }
                  }
                : null,
          ),
          // Step Over
          IconButton(
            icon: const Icon(Icons.redo,
                color: Colors.lightBlueAccent), // Approximate icon
            tooltip: 'Step Over',
            onPressed: isPaused ? vmManager.stepOver : null,
          ),
          // Step Into
          IconButton(
            icon:
                const Icon(Icons.arrow_downward, color: Colors.lightBlueAccent),
            tooltip: 'Step Into',
            onPressed: isPaused ? vmManager.stepInto : null,
          ),
          // Step Out
          IconButton(
            icon: const Icon(Icons.arrow_upward, color: Colors.lightBlueAccent),
            tooltip: 'Step Out',
            onPressed: isPaused ? vmManager.stepOut : null,
          ),
          // Stop / Disconnect
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.redAccent),
            tooltip: 'Stop',
            onPressed: isConnected ? vmManager.disconnect : null,
          ),
        ],
      ),
    );
  }
}

class FloatingDebugToolbar extends StatelessWidget {
  const FloatingDebugToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFF313244), width: 1),
      ),
      child: const DebugControls(),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF1E1E2E),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFBAC2DE),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _VariablesList extends ConsumerWidget {
  const _VariablesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vmManager = ref.watch(vmServiceManagerProvider);

    return StreamBuilder<List<vm.BoundVariable>>(
      stream: vmManager.variablesStream,
      builder: (context, snapshot) {
        final vars = snapshot.data ?? [];

        if (vars.isEmpty) {
          return const Center(
            child: Text(
              'No variables',
              style: TextStyle(color: Color(0xFF585B70), fontSize: 13),
            ),
          );
        }

        return ListView.builder(
          itemCount: vars.length,
          itemBuilder: (context, index) {
            final variable = vars[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${variable.name}: ',
                    style:
                        const TextStyle(color: Color(0xFF89B4FA), fontSize: 13),
                  ),
                  Expanded(
                    child: Text(
                      _getValue(variable.value),
                      style: const TextStyle(
                          color: Color(0xFFA6E3A1), fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getValue(dynamic value) {
    if (value is vm.InstanceRef) {
      return value.valueAsString ?? value.classRef?.name ?? 'Object';
    }
    return value.toString();
  }
}

class _CallStackList extends ConsumerWidget {
  const _CallStackList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vmManager = ref.watch(vmServiceManagerProvider);

    return StreamBuilder<List<vm.Frame>>(
      stream: vmManager.callStackStream,
      builder: (context, snapshot) {
        final frames = snapshot.data ?? [];

        if (frames.isEmpty) {
          return const Center(
            child: Text(
              'No call stack',
              style: TextStyle(color: Color(0xFF585B70), fontSize: 13),
            ),
          );
        }

        return ListView.builder(
          itemCount: frames.length,
          itemBuilder: (context, index) {
            final frame = frames[index];
            final name = frame.code?.name ?? 'Unknown';
            final uri = frame.location?.script?.uri ?? '';
            final fileName = uri.split('/').last;
            final line = frame.location?.line ?? '?';

            return ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              title: Text(name,
                  style:
                      const TextStyle(color: Color(0xFFCDD6F4), fontSize: 13)),
              subtitle: Text('$fileName:$line',
                  style:
                      const TextStyle(color: Color(0xFF7F849C), fontSize: 11)),
              onTap: () {
                // Future: Navigate to file/line
                print('Navigate to $uri:$line');
              },
            );
          },
        );
      },
    );
  }
}

class _BreakpointsList extends ConsumerWidget {
  const _BreakpointsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(breakpointsProvider);
    final bps = state.breakpoints;

    if (bps.isEmpty) {
      return const Center(
        child: Text(
          'No breakpoints',
          style: TextStyle(color: Color(0xFF585B70), fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      itemCount: bps.length,
      itemBuilder: (context, index) {
        final bp = bps[index];
        final filename = bp.path.split('/').last;
        final hasCondition = bp.condition != null && bp.condition!.isNotEmpty;

        return ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          leading: Icon(Icons.circle,
              color: hasCondition ? Colors.orange : Colors.red, size: 12),
          title: Text(
            filename,
            style: const TextStyle(color: Color(0xFFCDD6F4), fontSize: 13),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Line ${bp.line}',
                style: const TextStyle(color: Color(0xFF7F849C), fontSize: 11),
              ),
              if (hasCondition)
                Text(
                  'Condition: ${bp.condition}',
                  style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 10,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 14, color: Color(0xFFF38BA8)),
            onPressed: () => ref
                .read(breakpointsProvider.notifier)
                .toggleBreakpoint(bp.path, bp.line),
          ),
        );
      },
    );
  }
}

class _ExpressionInput extends ConsumerStatefulWidget {
  const _ExpressionInput();

  @override
  ConsumerState<_ExpressionInput> createState() => _ExpressionInputState();
}

class _ExpressionInputState extends ConsumerState<_ExpressionInput> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _evaluate() async {
    final expression = _controller.text.trim();
    if (expression.isEmpty) return;

    final vmManager = ref.read(vmServiceManagerProvider);

    // Call the simplified method that uses internal paused state
    final result = await vmManager.evaluateExpression(expression);

    if (!mounted) return;

    // Show result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Result: $result'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            // Copy logic would go here
          },
        ),
      ),
    );

    // Optionally keep text or clear? Let's keep for refinement.
    // _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _controller,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Evaluate expression...',
          hintStyle: const TextStyle(color: Color(0xFF585B70)),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFF1E1E2E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide.none,
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.send, size: 14, color: Color(0xFF89B4FA)),
            onPressed: _evaluate,
          ),
        ),
        onSubmitted: (_) => _evaluate(),
      ),
    );
  }
}
