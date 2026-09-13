import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
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
    _requestPermissions();
  }

  @override
  void dispose() {
    _controller.removeListener(_updateCursorPosition);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    // En Android 13+ file_picker maneja permisos automáticamente
    // Para versiones anteriores, permission_handler podría ser necesario
    // pero file_picker ya lo solicita al abrir el diálogo
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wordWrap = prefs.getBool('wordWrap') ?? false;
      _zoomLevel = prefs.getDouble('zoom') ?? 1.0;
      _showLineNumbers = prefs.getBool('lineNumbers') ?? false;
      // Cargar último contenido si existe
      final lastContent = prefs.getString('lastContent');
      if (lastContent != null && lastContent.isNotEmpty) {
        _controller.text = lastContent;
        _history.add(lastContent);
        _historyIndex = 0;
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wordWrap', _wordWrap);
    await prefs.setDouble('zoom', _zoomLevel);
    await prefs.setBool('lineNumbers', _showLineNumbers);
    await prefs.setString('lastContent', _controller.text);
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

  @override
  Widget build(BuildContext context) {
    final fontSize = 14.0 * _zoomLevel;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentFilePath == null ? 'DarkNote - Sin título' : 'DarkNote - ${_currentFilePath!.split('/').last}'),
        actions: [
          _buildMenu('Archivo', [
            const PopupMenuItem(value: 'nuevo', child: Text('Nuevo')),
            const PopupMenuItem(value: 'abrir', child: Text('Abrir')),
            const PopupMenuItem(value: 'guardar', child: Text('Guardar')),
            const PopupMenuItem(value: 'guardar_como', child: Text('Guardar como')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'exportar', child: Text('Exportar PDF (Pronto)')),
          ]),
          _buildMenu('Edición', [
            const PopupMenuItem(value: 'deshacer', child: Text('Deshacer')),
            const PopupMenuItem(value: 'rehacer', child: Text('Rehacer')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'buscar', child: Text('Buscar')),
            const PopupMenuItem(value: 'ir_linea', child: Text('Ir a línea')),
            const PopupMenuItem(value: 'seleccionar_todo', child: Text('Seleccionar todo')),
          ]),
          _buildMenu('Ver', [
            PopupMenuItem(value: 'ajuste', child: Text(_wordWrap ? 'Desactivar Ajuste' : 'Activar Ajuste')),
            PopupMenuItem(value: 'numeros', child: Text(_showLineNumbers ? 'Ocultar Números' : 'Mostrar Números')),
            const PopupMenuItem(value: 'zoom_in', child: Text('Zoom +')),
            const PopupMenuItem(value: 'zoom_out', child: Text('Zoom -')),
          ]),
          _buildMenu('Herramientas', [
            PopupMenuItem(value: 'terminal', child: Text(_terminalVisible ? 'Ocultar Terminal' : 'Mostrar Terminal')),
            const PopupMenuItem(value: 'ejecutar', child: Text('Ejecutar Código')),
            const PopupMenuItem(value: 'sintaxis', child: Text('Revisar Sintaxis')),
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
                      if (mounted) {
                        setState(() => _isTyping = false);
                        _updateCursorPosition();
                      }
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
                        List.generate(_totalLines > 0 ? _totalLines : 1, (i) => i + 1).join('\n'),
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
                  const Text("TERMINAL", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        "> Esperando comando...\n",
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

  PopupMenuButton<String> _buildMenu(String title, List<PopupMenuEntry<String>> items) {
    return PopupMenuButton<String>(
      tooltip: title,
      onSelected: (value) {
        _handleMenuAction(value);
      },
      itemBuilder: (context) => items,
    );
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'nuevo':
        _newFile();
        break;
      case 'abrir':
        _openFile();
        break;
      case 'guardar':
        _saveFile();
        break;
      case 'guardar_como':
        _saveFileAs();
        break;
      case 'deshacer':
        _undo();
        break;
      case 'rehacer':
        _redo();
        break;
      case 'buscar':
        _showSearchDialog();
        break;
      case 'ir_linea':
        _goToLine();
        break;
      case 'seleccionar_todo':
        _selectAll();
        break;
      case 'ajuste':
        _toggleWordWrap();
        break;
      case 'numeros':
        _toggleLineNumbers();
        break;
      case 'zoom_in':
        _adjustZoom(0.1);
        break;
      case 'zoom_out':
        _adjustZoom(-0.1);
        break;
      case 'terminal':
        _toggleTerminal();
        break;
      case 'ejecutar':
        _runCode();
        break;
      case 'sintaxis':
        _checkSyntax();
        break;
    }
  }

  void _newFile() {
    setState(() {
      _controller.clear();
      _currentFilePath = null;
      _history.clear();
      _historyIndex = -1;
    });
    _showMsg("Nuevo archivo creado");
  }

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'dart', 'js', 'py', 'java', 'cpp', 'c', 'h', 'html', 'css', 'json', 'xml', 'md'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        
        setState(() {
          _controller.text = content;
          _currentFilePath = result.files.single.path;
          _history.clear();
          _history.add(content);
          _historyIndex = 0;
        });
        _showMsg("Archivo abierto: ${result.files.single.name}");
        _savePreferences();
      } else {
        _showMsg("No se seleccionó ningún archivo");
      }
    } catch (e) {
      _showMsg("Error al abrir archivo: $e");
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
        _savePreferences();
      } catch (e) {
        _showMsg("Error al guardar: $e");
      }
    }
  }

  Future<void> _saveFileAs() async {
    try {
      // Guardar en la carpeta Documents del dispositivo
      Directory? directory = await getExternalStorageDirectory();
      String newPath = "";
      
      if (directory != null) {
        // Navegar hasta la carpeta Documents
        List<String> paths = directory.path.split('/');
        if (paths.length >= 5) {
          newPath = paths.sublist(0, paths.length - 4).join('/') + '/Documents';
        } else {
          newPath = directory.path;
        }
      } else {
        // Fallback a directorio temporal si falla
        directory = await getTemporaryDirectory();
        newPath = directory.path;
      }

      // Crear nombre de archivo con timestamp
      String fileName = "nota_${DateTime.now().millisecondsSinceEpoch}.txt";
      String fullPath = "$newPath/$fileName";
      
      File file = File(fullPath);
      await file.writeAsString(_controller.text);
      
      setState(() {
        _currentFilePath = fullPath;
      });
      
      _showMsg("Guardado en: $fullPath");
      _savePreferences();
    } catch (e) {
      _showMsg("Error al guardar como: $e");
    }
  }

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

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Buscar"),
        content: TextField(
          decoration: const InputDecoration(hintText: "Texto a buscar..."),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              // Lógica de búsqueda simple
              Navigator.pop(context);
              _showMsg("Función de búsqueda completa en desarrollo");
            },
            child: const Text("Buscar"),
          ),
        ],
      ),
    );
  }

  void _goToLine() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ir a Línea"),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Número de línea"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showMsg("Función Ir a Línea en desarrollo");
            },
            child: const Text("Ir"),
          ),
        ],
      ),
    );
  }

  void _selectAll() {
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    _showMsg("Todo el texto seleccionado");
  }

  void _toggleWordWrap() {
    setState(() => _wordWrap = !_wordWrap);
    _savePreferences();
    _showMsg(_wordWrap ? "Ajuste de línea activado" : "Ajuste de línea desactivado");
  }

  void _toggleLineNumbers() {
    setState(() => _showLineNumbers = !_showLineNumbers);
    _savePreferences();
    _showMsg(_showLineNumbers ? "Números de línea visibles" : "Números de línea ocultos");
  }

  void _adjustZoom(double delta) {
    setState(() {
      _zoomLevel = ((_zoomLevel + delta).clamp(0.5, 2.0));
    });
    _savePreferences();
    _showMsg("Zoom: ${(_zoomLevel * 100).toInt()}%");
  }

  void _toggleTerminal() {
    setState(() => _terminalVisible = !_terminalVisible);
  }

  void _runCode() {
    _showMsg("Ejecutando código simulado... (Requiere configuración de entorno)");
  }

  void _checkSyntax() {
    int openP = 0;
    int closeP = 0;
    
    // Contar paréntesis, llaves y corchetes
    for (var char in '({['.split('')) {
      openP += _controller.text.split(char).length - 1;
    }
    for (var char in ')}]'.split('')) {
      closeP += _controller.text.split(char).length - 1;
    }
    
    if (openP == closeP) {
      _showMsg("Sintaxis correcta: Paréntesis balanceados");
    } else {
      _showMsg("Error de sintaxis: $openP apertura(s), $closeP cierre(s)");
    }
  }

  void _showMsg(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }
}
