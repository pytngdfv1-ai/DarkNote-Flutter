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
  bool _highlightCurrentLine = false;
  bool _isReadOnly = false;
  bool _terminalVisible = false;
  
  final List<String> _history = [];
  int _historyIndex = -1;
  bool _isTyping = false;
  
  String? _currentFilePath;

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

  // --- FUNCIONES DE ARCHIVO CORREGIDAS ---

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'dart', 'js', 'py', 'json', 'xml', 'html'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        setState(() {
          _controller.text = content;
          _currentFilePath = file.path;
          _history.clear();
          _historyIndex = -1;
        });
        _showMsg("Archivo abierto: ${result.files.single.name}");
      } else {
        _showMsg("Operación cancelada");
      }
    } catch (e) {
      _showMsg("Error al abrir: $e");
    }
  }

  Future<void> _saveFile() async {
    if (_currentFilePath == null) {
      await _saveFileAs();
    } else {
      try {
        File file = File(_currentFilePath!);
        await file.writeAsString(_controller.text);
        _showMsg("Archivo guardado correctamente");
      } catch (e) {
        _showMsg("Error al guardar: $e");
      }
    }
  }

  Future<void> _saveFileAs() async {
    try {
      // Intentar obtener la carpeta de documentos
      Directory? directory = await getApplicationDocumentsDirectory();
      
      // Corrección del error de nulidad: Verificar si directory es null antes de usarlo
      String savePath;
      if (directory != null) {
        savePath = directory.path;
      } else {
        // Fallback a una ruta temporal si documents falla
        Directory? tempDir = await getTemporaryDirectory();
        savePath = tempDir?.path ?? '/sdcard/Documents';
      }

      String fileName = "nota_${DateTime.now().millisecondsSinceEpoch}.txt";
      String fullPath = '$savePath/$fileName';
      
      File file = File(fullPath);
      await file.writeAsString(_controller.text);
      
      setState(() {
        _currentFilePath = fullPath;
      });
      
      _showMsg("Guardado en: $fullPath");
    } catch (e) {
      _showMsg("Error grave al guardar: $e");
    }
  }

  // --- RESTO DE FUNCIONALIDADES ---

  void _newFile() {
    setState(() {
      _controller.clear();
      _currentFilePath = null;
      _history.clear();
      _historyIndex = -1;
    });
  }

  void _undo() {
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        _controller.text = _history[_historyIndex];
        _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
      });
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      setState(() {
        _historyIndex++;
        _controller.text = _history[_historyIndex];
        _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
      });
    }
  }

  void _showSearchDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Buscar"), content: const Text("Función Buscar (Pronto)")));
  }

  void _goToLine() {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Ir a Línea"), content: const Text("Ingresa número de línea")));
  }

  void _selectAll() {
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
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

  void _toggleTerminal() {
    setState(() => _terminalVisible = !_terminalVisible);
  }

  void _runCode() {
    _showMsg("Ejecutando código simulado...");
  }

  void _checkSyntax() {
    int openP = 0;
    int closeP = 0;
    try {
      openP = '({['.split('').fold(0, (sum, c) => sum + _controller.text.split(c).length - 1));
      closeP = ')}]'.split('').fold(0, (sum, c) => sum + _controller.text.split(c).length - 1));
    } catch (e) {
      // Ignorar errores de conteo
    }

    if (openP == closeP) {
      _showMsg("Sintaxis correcta (Paréntesis balanceados)");
    } else {
      _showMsg("Error de sintaxis: Paréntesis/Simbolos no balanceados");
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = 14.0 * _zoomLevel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DarkNote'),
        actions: [
          _buildMenu('Archivo', [
            MenuItem('Nuevo', () => _newFile()),
            MenuItem('Abrir', () => _openFile()),
            MenuItem('Guardar', () => _saveFile()),
            MenuItem('Guardar como', () => _saveFileAs()),
            const PopupMenuDivider(),
            MenuItem('Exportar PDF', () => _showMsg('Próximamente')),
          ]),
          _buildMenu('Edición', [
            MenuItem('Deshacer', () => _undo()),
            MenuItem('Rehacer', () => _redo()),
            const PopupMenuDivider(),
            MenuItem('Buscar', () => _showSearchDialog()),
            MenuItem('Ir a línea', () => _goToLine()),
            MenuItem('Seleccionar todo', () => _selectAll()),
          ]),
          _buildMenu('Ver', [
            MenuItem(_wordWrap ? 'Desactivar Ajuste' : 'Activar Ajuste', () => _toggleWordWrap()),
            MenuItem(_showLineNumbers ? 'Ocultar Números' : 'Mostrar Números', () => _toggleLineNumbers()),
            MenuItem('Zoom +', () => _adjustZoom(0.1)),
            MenuItem('Zoom -', () => _adjustZoom(-0.1)),
          ]),
          _buildMenu('Herramientas', [
            MenuItem(_terminalVisible ? 'Ocultar Terminal' : 'Mostrar Terminal', () => _toggleTerminal()),
            MenuItem('Ejecutar Código', () => _runCode()),
            MenuItem('Revisar Sintaxis', () => _checkSyntax()),
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
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 40,
                    child: Container(
                      color: const Color(0xFF252526),
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, top: 8),
                      child: Text(
                        List.generate(_totalLines > 1000 ? 1000 : _totalLines, (i) => i + 1).join('\n'),
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
                  const Text("TERMINAL", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        "> Esperando comando...\n> Listo.",
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
            Text('Ln $_currentLine, Col $_currentColumn', style: const TextStyle(fontSize: 12)),
            Text('Total: $_totalLines', style: const TextStyle(fontSize: 12)),
            Text('Chars: ${_controller.text.length}', style: const TextStyle(fontSize: 12)),
            Text(_wordWrap ? 'Wrap: ON' : 'Wrap: OFF', style: const TextStyle(fontSize: 12)),
            Text('Zoom: ${(_zoomLevel * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
            Text(_encoding, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        if (item is PopupMenuDivider) {
          return item;
        } else if (item is MenuItem) {
          return PopupMenuItem<String>(value: item.value, child: Text(item.label));
        }
        return null;
      }).whereType<PopupMenuEntry<String>>().toList(),
    );
  }
}

class MenuItem {
  final String label;
  final String value;
  final VoidCallback onTap;
  MenuItem(this.label, this.onTap) : value = label;
}
