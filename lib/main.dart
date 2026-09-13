import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

void main() {
  runApp(const DarkNoteApp());
}

class DarkNoteApp extends StatelessWidget {
  const DarkNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DarkNote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D2D2D),
          foregroundColor: Colors.white,
          elevation: 1,
        ),
        bottomAppBarTheme: const BottomAppBarTheme(
          color: Color(0xFF007ACC),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF252526),
          textStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const EditorScreen(),
    );
  }
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _controller = TextEditingController();
  String _currentFilePath = "";
  String _fileName = "Sin título";
  
  int _currentLine = 1;
  int _currentColumn = 1;
  int _totalLines = 1;
  
  bool _wordWrap = false;
  String _encoding = 'UTF-8';
  double _zoomLevel = 1.0;
  bool _showLineNumbers = false;
  bool _isReadOnly = false;
  bool _terminalVisible = false;
  
  final List<String> _history = [];
  int _historyIndex = -1;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateCursorPosition);
    _loadPreferences();
    _requestPermissions();
  }

  @override
  void dispose() {
    _controller.removeListener(_updateCursorPosition);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wordWrap = prefs.getBool('wordWrap') ?? false;
      _zoomLevel = prefs.getDouble('zoom') ?? 1.0;
      _showLineNumbers = prefs.getBool('lineNumbers') ?? false;
      // Cargar último contenido si existe
      final lastContent = prefs.getString('last_content');
      if (lastContent != null && lastContent.isNotEmpty) {
        _controller.text = lastContent;
        _addToHistory(lastContent);
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wordWrap', _wordWrap);
    await prefs.setDouble('zoom', _zoomLevel);
    await prefs.setBool('lineNumbers', _showLineNumbers);
    // Guardar contenido actual automáticamente
    await prefs.setString('last_content', _controller.text);
  }

  void _updateCursorPosition() {
    if (!_isTyping) return;
    setState(() {
      final text = _controller.text;
      final selection = _controller.selection;
      
      if (selection.isValid) {
        final beforeCursor = text.substring(0, selection.baseOffset);
        final lines = beforeCursor.split('\n');
        _currentLine = lines.length;
        _currentColumn = lines.last.length + 1;
        _totalLines = text.split('\n').length;
      }
    });
  }

  void _addToHistory(String text) {
    if (_historyIndex == -1 || _history[_historyIndex] != text) {
      if (_historyIndex < _history.length - 1) {
        _history.removeRange(_historyIndex + 1, _history.length);
      }
      _history.add(text);
      _historyIndex++;
      if (_history.length > 50) _history.removeAt(0); // Limitar historial
    }
  }

  // --- FUNCIONES REALES DE ARCHIVO ---

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'dart', 'js', 'html', 'css', 'md', 'json', 'xml'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        setState(() {
          _controller.text = content;
          _currentFilePath = file.path;
          _fileName = result.files.single.name;
          _addToHistory(content);
        });
        _showMsg("Archivo abierto: $_fileName");
        _savePreferences();
      }
    } catch (e) {
      _showMsg("Error al abrir archivo: $e");
    }
  }

  Future<void> _saveFile() async {
    if (_currentFilePath.isEmpty) {
      await _saveFileAs();
    } else {
      try {
        File file = File(_currentFilePath);
        await file.writeAsString(_controller.text);
        _showMsg("Archivo guardado exitosamente");
        _savePreferences();
      } catch (e) {
        _showMsg("Error al guardar: $e");
      }
    }
  }

  Future<void> _saveFileAs() async {
    try {
      String? filePath = await FilePicker.platform.saveFile(
        dialogTitle: "Guardar archivo como",
        fileName: _fileName == "Sin título" ? "nota.txt" : _fileName,
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (filePath != null) {
        File file = File(filePath);
        await file.writeAsString(_controller.text);
        setState(() {
          _currentFilePath = filePath;
          _fileName = filePath.split('/').last;
        });
        _showMsg("Archivo guardado en: $filePath");
        _savePreferences();
      }
    } catch (e) {
      _showMsg("Error al guardar como: $e");
    }
  }

  Future<void> _newFile() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nuevo Archivo"),
        content: const Text("¿Perderás los cambios no guardados. Continuar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sí, nuevo")),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _controller.clear();
        _currentFilePath = "";
        _fileName = "Sin título";
        _history.clear();
        _historyIndex = -1;
      });
      _savePreferences();
    }
  }

  // --- OTRAS FUNCIONALIDADES ---

  void _undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _controller.text = _history[_historyIndex];
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _controller.text = _history[_historyIndex];
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    }
  }

  void _selectAll() {
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
  }

  void _goToLine() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ir a Línea"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Número de línea"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              int line = int.tryParse(ctrl.text) ?? 1;
              if (line > 0 && line <= _totalLines) {
                // Lógica simple para ir a línea
                int pos = 0;
                int currentL = 1;
                for (int i = 0; i < _controller.text.length; i++) {
                  if (currentL == line) { pos = i; break; }
                  if (_controller.text[i] == '\n') currentL++;
                }
                _controller.selection = TextSelection(baseOffset: pos, extentOffset: pos);
              }
            },
            child: const Text("Ir"),
          )
        ],
      ),
    );
  }

  void _toggleWordWrap() {
    setState(() => _wordWrap = !_wordWrap);
    _savePreferences();
  }

  void _toggleLineNumbers() {
    setState(() => _showLineNumbers = !_showLineNumbers);
    _savePreferences();
  }

  void _adjustZoom(double delta) {
    setState(() => _zoomLevel = ((_zoomLevel + delta).clamp(0.5, 2.0)));
    _savePreferences();
  }

  void _toggleTerminal() {
    setState(() => _terminalVisible = !_terminalVisible);
  }

  void _runCode() {
    setState(() => _terminalVisible = true);
    _showMsg("Ejecutando... (Simulación en terminal)");
  }

  void _checkSyntax() {
    if (_controller.text.isEmpty) {
      _showMsg("Archivo vacío.");
      return;
    }
    // Verificación muy básica de paréntesis
    int openP = '({['.split('').fold(0, (sum, c) => sum + _controller.text.split(c).length - 1));
    int closeP = ')}]'.split('').fold(0, (sum, c) => sum + _controller.text.split(c).length - 1));
    
    if (openP == closeP) {
      _showMsg("Sintaxis parece correcta (Paréntesis balanceados).");
    } else {
      _showMsg("Posible error de sintaxis: Paréntesis no balanceados.");
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2), backgroundColor: Colors.grey[800]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = 14.0 * _zoomLevel;

    return Scaffold(
      appBar: AppBar(
        title: Text('DarkNote - $_fileName'),
        actions: [
          _buildMenu('Archivo', [
            MenuItem('Nuevo', _newFile),
            MenuItem('Abrir', _openFile),
            MenuItem('Guardar', _saveFile),
            MenuItem('Guardar como', _saveFileAs),
            const PopupMenuDivider(),
            MenuItem('Cerrar pestaña', _newFile), // Reutiliza lógica de nuevo por ahora
          ]),
          _buildMenu('Edición', [
            MenuItem('Deshacer', _undo),
            MenuItem('Rehacer', _redo),
            const PopupMenuDivider(),
            MenuItem('Buscar', () => _showMsg("Buscar: Usa Ctrl+F (Pronto)")),
            MenuItem('Ir a línea', _goToLine),
            MenuItem('Seleccionar todo', _selectAll),
          ]),
          _buildMenu('Ver', [
            MenuItem(_wordWrap ? 'Desactivar Ajuste' : 'Activar Ajuste', _toggleWordWrap),
            MenuItem(_showLineNumbers ? 'Ocultar Números' : 'Mostrar Números', _toggleLineNumbers),
            MenuItem('Zoom +', () => _adjustZoom(0.1)),
            MenuItem('Zoom -', () => _adjustZoom(-0.1)),
          ]),
          _buildMenu('Herramientas', [
            MenuItem(_terminalVisible ? 'Ocultar Terminal' : 'Mostrar Terminal', _toggleTerminal),
            MenuItem('Ejecutar Código', _runCode),
            MenuItem('Revisar Sintaxis', _checkSyntax),
          ]),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: fontSize,
                    color: Colors.white,
                    height: 1.5,
                  ),
                  readOnly: _isReadOnly,
                  decoration: const InputDecoration(
                    hintText: 'Escribe aquí...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(8.0),
                  ),
                  cursorColor: Colors.white,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (val) {
                    setState(() {
                      _isTyping = true;
                      _addToHistory(val);
                    });
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if(mounted) setState(() => _isTyping = false);
                      _updateCursorPosition();
                    });
                  },
                ),
                if (_showLineNumbers)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 45,
                    child: Container(
                      color: const Color(0xFF252526),
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 5, top: 8),
                      child: Text(
                        List.generate(_totalLines, (i) => i + 1).join('\n'),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: fontSize,
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_terminalVisible)
            Container(
              height: 150,
              color: const Color(0xFF111111),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("TERMINAL", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        "> Sistema listo.\n> Esperando comando...\n",
                        style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 8),
            Text('Ln $_currentLine, Col $_currentColumn', style: const TextStyle(fontSize: 12, color: Colors.white)),
            Text('Total: $_totalLines', style: const TextStyle(fontSize: 12, color: Colors.white)),
            Text('Chars: ${_controller.text.length}', style: const TextStyle(fontSize: 12, color: Colors.white)),
            Text(_wordWrap ? 'Wrap: ON' : 'Wrap: OFF', style: const TextStyle(fontSize: 12, color: Colors.white)),
            Text('Zoom: ${(_zoomLevel * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: Colors.white)),
            Text(_encoding, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  PopupMenuButton<String> _buildMenu(String title, List<dynamic> items) {
    return PopupMenuButton<String>(
      tooltip: title,
      onSelected: (value) {
        final item = items.firstWhere((i) => i is MenuItem && i.value == value, orElse: () => MenuItem('', () {})) as MenuItem;
        item.onTap();
      },
      itemBuilder: (context) => items.map((item) {
        if (item is PopupMenuDivider) return item;
        if (item is MenuItem) {
          return PopupMenuItem(value: item.value, child: Text(item.label));
        }
        return null;
      }).where((e) => e != null).cast<PopupMenuEntry<String>>().toList(),
    );
  }
}

class MenuItem {
  final String label;
  final String value;
  final VoidCallback onTap;
  MenuItem(this.label, this.onTap) : value = label;
}
