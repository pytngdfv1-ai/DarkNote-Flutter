import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
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
  int _currentLine = 1;
  int _currentColumn = 1;
  int _totalLines = 1;
  
  bool _wordWrap = false;
  String _encoding = 'UTF-8';
  double _zoomLevel = 1.0;
  bool _showLineNumbers = false;
  bool _isReadOnly = false;
  bool _terminalVisible = false;
  
  String? _currentFilePath;
  String _currentFileName = "Sin título";

  final List<String> _history = [];
  int _historyIndex = -1;
  bool _isTyping = false;

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
      _zoomLevel = prefs.getDouble('zoom') ?? 1.0;
      _showLineNumbers = prefs.getBool('lineNumbers') ?? false;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wordWrap', _wordWrap);
    await prefs.setDouble('zoom', _zoomLevel);
    await prefs.setBool('lineNumbers', _showLineNumbers);
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

  // --- FUNCIONES DE ARCHIVO REALES ---

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, // Parámetro universal
        allowedExtensions: ['txt', 'md', 'dart', 'js', 'html', 'css', 'json', 'xml'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        setState(() {
          _controller.text = content;
          _currentFilePath = file.path;
          _currentFileName = result.files.single.name;
          _history.clear();
          _history.add(content);
          _historyIndex = 0;
        });
        _showMsg("Archivo abierto: $_currentFileName");
      } else {
        _showMsg("Operación cancelada");
      }
    } catch (e) {
      _showMsg("Error al abrir: $e");
    }
  }

  Future<void> _saveFile() async {
    if (_currentFilePath != null) {
      await _writeToFile(_currentFilePath!);
    } else {
      await _saveFileAs();
    }
  }

  Future<void> _saveFileAs() async {
    try {
      // CORRECCIÓN: Usamos 'type' en lugar de 'fileType' para compatibilidad total
      String? filePath = await FilePicker.platform.saveFile(
        dialogTitle: "Guardar archivo como...",
        fileName: _currentFileName == "Sin título" ? "nota_${DateTime.now().millisecondsSinceEpoch}.txt" : _currentFileName,
        type: FileType.custom, 
        allowedExtensions: ['txt', 'md', 'dart', 'js', 'html'],
      );

      if (filePath != null) {
        // Asegurar extensión .txt si no tiene
        if (!filePath.endsWith('.txt') && !filePath.endsWith('.md')) {
           filePath = "$filePath.txt";
        }
        await _writeToFile(filePath);
        setState(() {
          _currentFilePath = filePath;
          // CORRECCIÓN: Verificación de nulo antes de hacer split
          _currentFileName = filePath.split('/').last; 
        });
      } else {
        _showMsg("Guardado cancelado");
      }
    } catch (e) {
      _showMsg("Error al guardar: $e");
    }
  }

  Future<void> _writeToFile(String path) async {
    try {
      File file = File(path);
      await file.writeAsString(_controller.text);
      _showMsg("Archivo guardado exitosamente en:\n$path");
    } catch (e) {
      _showMsg("Fallo crítico al escribir: $e");
    }
  }

  // --- FUNCIONES DE EDICIÓN ---

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

  void _checkSyntax() {
    int openP = 0;
    int closeP = 0;
    for (var c in '({['.split('')) {
      openP += _controller.text.split(c).length - 1;
    }
    for (var c in ')}]'.split('')) {
      closeP += _controller.text.split(c).length - 1;
    }
    
    if (openP == closeP) {
      _showMsg("Sintaxis válida: Paréntesis y llaves balanceados.");
    } else {
      _showMsg("Error de sintaxis: Faltan ${openP > closeP ? 'cierres' : 'aperturas'}.");
    }
  }

  void _toggleTerminal() {
    setState(() => _terminalVisible = !_terminalVisible);
  }

  void _runCode() {
    _showMsg("Ejecutando simulación... (Salida en terminal)");
  }

  void _showSearchDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Buscar"), content: const Text("Función Buscar (Pendiente de UI completa)")));
  }

  void _goToLine() {
     showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Ir a Línea"), content: const Text("Ingresa número (Pendiente)")));
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
    setState(() {
      _zoomLevel = ((_zoomLevel + delta).clamp(0.5, 2.0));
    });
    _savePreferences();
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = 14.0 * _zoomLevel;

    return Scaffold(
      appBar: AppBar(
        title: Text('DarkNote - $_currentFileName'),
        actions: [
          _buildMenu('Archivo', [
            _menuItem('Nuevo', Icons.note_add, () => setState(() { _controller.clear(); _currentFilePath = null; _currentFileName = "Sin título"; })),
            _menuItem('Abrir', Icons.folder_open, _openFile),
            _menuItem('Guardar', Icons.save, _saveFile),
            _menuItem('Guardar como', Icons.save_as, _saveFileAs),
            const PopupMenuDivider(),
            _menuItem('Exportar PDF', Icons.picture_as_pdf, () => _showMsg("Próximamente")),
          ]),
          _buildMenu('Edición', [
            _menuItem('Deshacer', Icons.undo, _undo),
            _menuItem('Rehacer', Icons.redo, _redo),
            const PopupMenuDivider(),
            _menuItem('Buscar', Icons.search, _showSearchDialog),
            _menuItem('Ir a línea', Icons.arrow_downward, _goToLine),
            _menuItem('Seleccionar todo', Icons.select_all, _selectAll),
          ]),
          _buildMenu('Ver', [
            _menuItem(_wordWrap ? 'Desactivar Ajuste' : 'Activar Ajuste', Icons.wrap_text, _toggleWordWrap),
            _menuItem(_showLineNumbers ? 'Ocultar Números' : 'Mostrar Números', Icons.format_list_numbered, _toggleLineNumbers),
            const PopupMenuDivider(),
            _menuItem('Zoom +', Icons.add, () => _adjustZoom(0.1)),
            _menuItem('Zoom -', Icons.remove, () => _adjustZoom(-0.1)),
          ]),
          _buildMenu('Herramientas', [
            _menuItem(_terminalVisible ? 'Ocultar Terminal' : 'Mostrar Terminal', Icons.terminal, _toggleTerminal),
            _menuItem('Ejecutar Código', Icons.play_arrow, _runCode),
            _menuItem('Revisar Sintaxis', Icons.check_circle_outline, _checkSyntax),
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
                    contentPadding: EdgeInsets.all(16.0),
                  ),
                  cursorColor: Colors.white,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (val) {
                    setState(() {
                      _isTyping = true;
                      if (_historyIndex == -1 || _history[_historyIndex] != val) {
                        if (_historyIndex < _history.length - 1) {
                          _history.removeRange(_historyIndex + 1, _history.length);
                        }
                        _history.add(val);
                        _historyIndex++;
                      }
                    });
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if(mounted) setState(() => _isTyping = false);
                      _updateCursorPosition();
                    });
                  },
                ),
                if (_showLineNumbers)
                  Positioned(
                    left: 0, top: 0, bottom: 0, width: 45,
                    child: Container(
                      color: const Color(0xFF252526),
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, top: 16),
                      child: Text(
                        List.generate(_totalLines > 1000 ? 1000 : _totalLines, (i) => i + 1).join('\n'),
                        style: TextStyle(color: Colors.grey[600], fontSize: fontSize, fontFamily: 'monospace', height: 1.5),
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
                  Row(children: [const Text("TERMINAL", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.close, size: 16), onPressed: _toggleTerminal)]),
                  Expanded(child: SingleChildScrollView(child: Text("> Sistema listo.\n> Esperando comando...\n", style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12)))),
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
            Text('Total: $_totalLines', style: const TextStyle(fontSize: 12)),
            Text('Chars: ${_controller.text.length}', style: const TextStyle(fontSize: 12)),
            Text(_wordWrap ? 'Wrap: ON' : 'OFF', style: const TextStyle(fontSize: 12)),
            Text('Zoom: ${(_zoomLevel * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
            Text(_encoding, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  // Helper para crear items de menú correctamente tipados
  PopupMenuItem<dynamic> _menuItem(String label, IconData icon, VoidCallback onTap) {
    return PopupMenuItem<dynamic>(
      value: label,
      child: ListTile(
        leading: Icon(icon, size: 20),
        title: Text(label),
        contentPadding: EdgeInsets.zero,
        horizontalTitleGap: 8,
        minLeadingWidth: 24,
      ),
      onTap: onTap,
    );
  }

  PopupMenuButton<dynamic> _buildMenu(String title, List<dynamic> items) {
    return PopupMenuButton<dynamic>(
      tooltip: title,
      icon: Icon(_getIconForMenu(title)),
      onSelected: (value) {
        // La acción se maneja dentro del item
      },
      itemBuilder: (context) => items,
    );
  }

  IconData _getIconForMenu(String title) {
    switch (title) {
      case 'Archivo': return Icons.menu_book;
      case 'Edición': return Icons.edit;
      case 'Ver': return Icons.visibility;
      case 'Herramientas': return Icons.build;
      default: return Icons.more_vert;
    }
  }
}
