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
  
  String? _filePath; // Ruta del archivo actual
  String _fileName = "Sin título";
  
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
        type: FileType.custom,
        allowedExtensions: ['txt', 'dart', 'js', 'py', 'md', 'json', 'xml', 'html', 'css'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        String content = await File(file.path!).readAsString();
        
        setState(() {
          _controller.text = content;
          _filePath = file.path;
          _fileName = file.name;
          _history.clear();
          _history.add(content);
          _historyIndex = 0;
        });
        
        _showMsg("Archivo '${file.name}' abierto correctamente");
      }
    } catch (e) {
      _showMsg("Error al abrir archivo: $e");
    }
  }

  Future<void> _saveFile() async {
    if (_filePath == null) {
      await _saveFileAs();
    } else {
      try {
        await File(_filePath!).writeAsString(_controller.text);
        _showMsg("Archivo guardado correctamente");
      } catch (e) {
        _showMsg("Error al guardar: $e");
      }
    }
  }

  Future<void> _saveFileAs() async {
    try {
      // En Android, guardamos directamente en la carpeta Documents por simplicidad y permisos
      final directory = await getExternalStorageDirectory();
      final docPath = directory?.parent.parent.parent.parent.path + '/Documents';
      
      if (docPath != null) {
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String fileName = "nota_$timestamp.txt";
        String fullPath = '$docPath/$fileName';
        
        await File(fullPath).writeAsString(_controller.text);
        
        setState(() {
          _filePath = fullPath;
          _fileName = fileName;
        });
        
        _showMsg("Guardado como: $fileName en Documentos");
      } else {
        _showMsg("No se pudo acceder a la carpeta de documentos");
      }
    } catch (e) {
      _showMsg("Error al guardar como: $e");
    }
  }

  void _newFile() {
    setState(() {
      _controller.clear();
      _filePath = null;
      _fileName = "Sin título";
      _history.clear();
      _historyIndex = -1;
    });
  }

  // --- FUNCIONES DE EDICIÓN ---

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

  void _selectAll() {
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
  }

  void _checkSyntax() {
    int openP = 0;
    int closeP = 0;
    for (var c in _controller.text.split('')) {
      if ('({['.contains(c)) openP++;
      if (')}]'.contains(c)) closeP++;
    }
    
    String msg = (openP == closeP) 
        ? "Sintaxis válida: Paréntesis/llaves balanceados." 
        : "Error de sintaxis: Faltan ${openP > closeP ? (openP - closeP).toString() + ' cierres' : (closeP - openP).toString() + ' aperturas'}.";
    
    _showMsg(msg);
  }

  void _runCode() {
    _showMsg("Ejecutando simulación... (Requiere configuración de entorno específica)");
  }

  // --- UI HELPERS ---

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

  void _showSearchDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Buscar"),
      content: TextField(
        decoration: const InputDecoration(hintText: "Texto a buscar"),
        onChanged: (val) {
          // Lógica simple de búsqueda
          int index = _controller.text.indexOf(val);
          if (index != -1) {
            _controller.selection = TextSelection(baseOffset: index, extentOffset: index + val.length);
          }
        },
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar"))],
    ));
  }

  void _goToLine() {
    TextEditingController lineCtrl = TextEditingController(text: "$_currentLine");
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Ir a Línea"),
      content: TextField(
        controller: lineCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: "Número de línea"),
      ),
      actions: [
        TextButton(onPressed: () {
          int targetLine = int.tryParse(lineCtrl.text) ?? 1;
          if (targetLine > 0 && targetLine <= _totalLines) {
            int offset = 0;
            List<String> lines = _controller.text.split('\n');
            for (int i = 0; i < targetLine - 1; i++) {
              offset += lines[i].length + 1;
            }
            _controller.selection = TextSelection.fromPosition(TextPosition(offset: offset));
          }
          Navigator.pop(context);
        }, child: const Text("Ir")),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
      ],
    ));
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.grey[800],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = 14.0 * _zoomLevel;

    return Scaffold(
      appBar: AppBar(
        title: Text(_fileName),
        actions: [
          // Menú Archivo
          PopupMenuButton<String>(
            tooltip: 'Archivo',
            onSelected: (value) {
              if (value == 'nuevo') _newFile();
              else if (value == 'abrir') _openFile();
              else if (value == 'guardar') _saveFile();
              else if (value == 'guardar_como') _saveFileAs();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'nuevo', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(Icons.note_add), title: Text('Nuevo'))),
              const PopupMenuItem(value: 'abrir', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(Icons.folder_open), title: Text('Abrir'))),
              const PopupMenuItem(value: 'guardar', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(Icons.save), title: Text('Guardar'))),
              const PopupMenuItem(value: 'guardar_como', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(Icons.save_as), title: Text('Guardar como'))),
            ],
          ),
          // Menú Edición
          PopupMenuButton<String>(
            tooltip: 'Edición',
            onSelected: (value) {
              if (value == 'deshacer') _undo();
              else if (value == 'rehacer') _redo();
              else if (value == 'buscar') _showSearchDialog();
              else if (value == 'ir_linea') _goToLine();
              else if (value == 'seleccionar_todo') _selectAll();
              else if (value == 'sintaxis') _checkSyntax();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'deshacer', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(Icons.undo), title: Text('Deshacer'))),
              const PopupMenuItem(value: 'rehacer', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(Icons.redo), title: Text('Rehacer'))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'buscar', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(Icons.search), title: Text('Buscar'))),
              const PopupMenuItem(value: 'ir_linea', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(Icons.arrow_downward), title: Text('Ir a línea'))),
              const PopupMenuItem(value: 'seleccionar_todo', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(Icons.select_all), title: Text('Seleccionar todo'))),
              const PopupMenuItem(value: 'sintaxis', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(Icons.code), title: Text('Revisar Sintaxis'))),
            ],
          ),
          // Menú Ver
          PopupMenuButton<String>(
            tooltip: 'Ver',
            onSelected: (value) {
              if (value == 'wrap') _toggleWordWrap();
              else if (value == 'numbers') _toggleLineNumbers();
              else if (value == 'zoom_in') _adjustZoom(0.1);
              else if (value == 'zoom_out') _adjustZoom(-0.1);
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(value: 'wrap', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(_wordWrap ? Icons.check_box : Icons.check_box_outline_blank), title: const Text('Ajuste de línea'))),
              PopupMenuItem(value: 'numbers', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(_showLineNumbers ? Icons.check_box : Icons.check_box_outline_blank), title: const Text('Números de línea'))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'zoom_in', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(Icons.add), title: Text('Zoom +'))),
              const PopupMenuItem(value: 'zoom_out', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(Icons.remove), title: Text('Zoom -'))),
            ],
          ),
          // Menú Herramientas
          PopupMenuButton<String>(
            tooltip: 'Herramientas',
            onSelected: (value) {
              if (value == 'terminal') _toggleTerminal();
              else if (value == 'run') _runCode();
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(value: 'terminal', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(_terminalVisible ? Icons.visibility_off : Icons.terminal), title: Text(_terminalVisible ? 'Ocultar Terminal' : 'Mostrar Terminal'))),
              const PopupMenuItem(value: 'run', child: ListTile(horizontalTitleGap: 8, dense: true, leading: Icon(Icons.play_arrow), title: Text('Ejecutar'))),
            ],
          ),
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
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(8.0),
                  ),
                  cursorColor: Colors.white,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (val) {
                    setState(() {
                      _isTyping = true;
                      if (_historyIndex == -1 || _history.isEmpty || _history[_historyIndex] != val) {
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
                    width: 45,
                    child: Container(
                      color: const Color(0xFF252526),
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, top: 8),
                      child: SingleChildScrollView(
                        child: Text(
                          List.generate(_totalLines, (i) => '${i + 1}\n').join(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: fontSize,
                            fontFamily: 'monospace',
                            height: 1.5,
                          ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("TERMINAL", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), onPressed: _toggleTerminal)
                    ],
                  ),
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
            Flexible(child: Text('Ln $_currentLine, Col $_currentColumn', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
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
}
