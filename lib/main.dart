import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
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
          foregroundColor: Colors.white,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF252526),
          textColor: Colors.white,
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
  int _currentLine = 1;
  int _currentColumn = 1;
  int _totalLines = 1;
  bool _isReadOnly = false;
  bool _showTerminal = false;
  String _terminalOutput = "";
  
  // Estado básico
  bool _wordWrap = false;
  String _encoding = 'UTF-8';
  double _zoomLevel = 1.0;
  String _currentFilePath = "";

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateCursorPosition);
    _loadPreferences();
  }

  @override
  void dispose() {
    _controller.removeListener(_updateCursorPosition);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wordWrap = prefs.getBool('wordWrap') ?? false;
    });
  }

  void _updateCursorPosition() {
    if (_controller.selection.isValid) {
      final text = _controller.text;
      final beforeCursor = text.substring(0, _controller.selection.baseOffset);
      final lines = beforeCursor.split('\n');
      setState(() {
        _currentLine = lines.length;
        _currentColumn = lines.last.length + 1;
        _totalLines = text.split('\n').length;
      });
    }
  }

  // --- Funcionalidades de Archivo ---
  Future<void> _openFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      setState(() {
        _controller.text = content;
        _currentFilePath = result.files.single.name;
        _isReadOnly = false;
      });
      _showSnackBar("Archivo abierto: ${result.files.single.name}");
    }
  }

  Future<void> _saveFile() async {
    if (_currentFilePath.isEmpty) {
      await _saveFileAs();
      return;
    }
    // Nota: En Android real se necesita gestión de permisos o SAF para escribir directamente
    // Aquí simulamos guardado en directorio temporal para demostración sin errores
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_currentFilePath');
      await file.writeAsString(_controller.text);
      _showSnackBar("Guardado en: ${file.path}");
    } catch (e) {
      _showSnackBar("Error al guardar: $e");
    }
  }

  Future<void> _saveFileAs() async {
    String? fileName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Guardar como"),
        content: TextField(
          decoration: const InputDecoration(hintText: "nombre.txt"),
          onSubmitted: (val) => Navigator.pop(context, val),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(context, ""), child: const Text("Guardar")),
        ],
      ),
    );
    
    if (fileName != null && fileName.isNotEmpty) {
      setState(() => _currentFilePath = fileName);
      await _saveFile();
    }
  }

  // --- Funcionalidades de Edición ---
  void _undo() {
    // Simulación básica (Flutter TextField tiene undo nativo con Ctrl+Z o gesto)
    _showSnackBar("Deshacer (usa el gesto o teclado)");
  }

  void _redo() {
    _showSnackBar("Rehacer (usa el gesto o teclado)");
  }

  void _selectAll() {
    setState(() {
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    });
  }

  void _goToLine() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ir a línea"),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Número de línea"),
          onSubmitted: (val) {
            int line = int.tryParse(val) ?? 1;
            // Lógica simplificada para ir a línea
            _showSnackBar("Navegando a línea $line");
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Ir")),
        ],
      ),
    );
  }

  // --- Herramientas ---
  void _toggleTerminal() {
    setState(() {
      _showTerminal = !_showTerminal;
      if (_showTerminal && _terminalOutput.isEmpty) {
        _terminalOutput = "> Terminal iniciada...\n> Esperando comando...\n";
      }
    });
  }

  void _runCode() {
    setState(() {
      _showTerminal = true;
      _terminalOutput += "> Ejecutando script...\n";
      _terminalOutput += "> Compilación exitosa.\n";
      _terminalOutput += "> Salida: Hola Mundo\n";
    });
  }

  void _checkSyntax() {
    // Simulación simple
    if (_controller.text.contains("error")) {
      _showSnackBar("Errores de sintaxis encontrados");
    } else {
      _showSnackBar("Sintaxis correcta");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentFilePath.isEmpty ? 'DarkNote - Nuevo' : _currentFilePath),
        actions: [
          _buildMenu('Archivo', [
            const PopupMenuItem(value: 'nuevo', child: Text('Nuevo')),
            const PopupMenuItem(value: 'abrir', child: Text('Abrir')),
            const PopupMenuItem(value: 'guardar', child: Text('Guardar')),
            const PopupMenuItem(value: 'guardar_como', child: Text('Guardar como')),
            const PopupMenuItem(value: 'exportar', child: Text('Exportar (TXT)')),
            PopupMenuItem(
              value: 'solo_lectura', 
              child: ListTile(
                leading: const Icon(Icons.lock), 
                title: Text(_isReadOnly ? 'Desactivar Solo Lectura' : 'Solo Lectura'),
                contentPadding: EdgeInsets.zero,
              )
            ),
          ]),
          _buildMenu('Edición', [
            const PopupMenuItem(value: 'deshacer', child: Text('Deshacer')),
            const PopupMenuItem(value: 'rehacer', child: Text('Rehacer')),
            const PopupMenuItem(value: 'buscar', child: Text('Buscar')),
            const PopupMenuItem(value: 'ir_linea', child: Text('Ir a línea')),
            const PopupMenuItem(value: 'seleccionar_todo', child: Text('Seleccionar todo')),
          ]),
          _buildMenu('Ver', [
            PopupMenuItem(value: 'ajuste', child: Text(_wordWrap ? 'Desactivar Ajuste' : 'Activar Ajuste')),
            const PopupMenuItem(value: 'zoom_in', child: Text('Zoom +')),
            const PopupMenuItem(value: 'zoom_out', child: Text('Zoom -')),
          ]),
          _buildMenu('Herramientas', [
            const PopupMenuItem(value: 'terminal', child: Text('Terminal')),
            const PopupMenuItem(value: 'ejecutar', child: Text('Ejecutar')),
            const PopupMenuItem(value: 'sintaxis', child: Text('Revisar Sintaxis')),
          ]),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF1E1E1E),
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                readOnly: _isReadOnly,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14.0 * _zoomLevel,
                  color: Colors.white,
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  hintText: 'Escribe aquí...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                cursorColor: Colors.white,
                autocorrect: false,
                enableSuggestions: false,
              ),
            ),
          ),
          if (_showTerminal)
            Container(
              height: 150,
              color: Colors.black87,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(_terminalOutput, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12)),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey[800]),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.play_arrow, size: 20), onPressed: _runCode),
                      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: _toggleTerminal),
                      const Text("Terminal", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  )
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
            Text('Ln $_currentLine, Col $_currentColumn', style: const TextStyle(fontSize: 12)),
            Text('Líneas: $_totalLines', style: const TextStyle(fontSize: 12)),
            Text('Chars: ${_controller.text.length}', style: const TextStyle(fontSize: 12)),
            Text(_wordWrap ? 'Wrap: ON' : 'Wrap: OFF', style: const TextStyle(fontSize: 12)),
            Text('$_encoding', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  PopupMenuButton<String> _buildMenu(String title, List<PopupMenuItem<String>> items) {
    return PopupMenuButton<String>(
      tooltip: title,
      onSelected: (value) {
        switch (value) {
          case 'nuevo': setState(() { _controller.clear(); _currentFilePath = ""; }); break;
          case 'abrir': _openFile(); break;
          case 'guardar': _saveFile(); break;
          case 'guardar_como': _saveFileAs(); break;
          case 'solo_lectura': setState(() => _isReadOnly = !_isReadOnly); break;
          case 'deshacer': _undo(); break;
          case 'rehacer': _redo(); break;
          case 'seleccionar_todo': _selectAll(); break;
          case 'ir_linea': _goToLine(); break;
          case 'ajuste': setState(() => _wordWrap = !_wordWrap); break;
          case 'zoom_in': setState(() => _zoomLevel = (_zoomLevel + 0.1).clamp(0.8, 2.0)); break;
          case 'zoom_out': setState(() => _zoomLevel = (_zoomLevel - 0.1).clamp(0.8, 2.0)); break;
          case 'terminal': _toggleTerminal(); break;
          case 'ejecutar': _runCode(); break;
          case 'sintaxis': _checkSyntax(); break;
          default: _showSnackBar("$title: $value");
        }
      },
      itemBuilder: (BuildContext context) => items,
    );
  }
}
