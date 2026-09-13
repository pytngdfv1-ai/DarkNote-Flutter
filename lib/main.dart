import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';

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
  String _currentFilePath = "";
  String _fileName = "Sin título";
  
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
    // En Android 13+ file_picker maneja permisos automáticamente al seleccionar
    // No necesitamos pedir permisos de almacenamiento explícitos para usar FilePicker
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
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wordWrap', _wordWrap);
    await prefs.setDouble('zoom', _zoomLevel);
    await prefs.setBool('lineNumbers', _showLineNumbers);
    // Guardar contenido actual como respaldo
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

  @override
  Widget build(BuildContext context) {
    final fontSize = 14.0 * _zoomLevel;

    return Scaffold(
      appBar: AppBar(
        title: Text('DarkNote - $_fileName'),
        actions: [
          _buildMenu('Archivo', [
            _menuItem('Nuevo', () => _newFile()),
            _menuItem('Abrir', () => _openFile()),
            _menuItem('Guardar', () => _saveFile()),
            _menuItem('Guardar como', () => _saveFileAs()),
            const PopupMenuDivider(),
            _menuItem('Exportar PDF (Pronto)', () => _showMsg('Función en desarrollo')),
          ]),
          _buildMenu('Edición', [
            _menuItem('Deshacer', () => _undo()),
            _menuItem('Rehacer', () => _redo()),
            const PopupMenuDivider(),
            _menuItem('Buscar', () => _showSearchDialog()),
            _menuItem('Ir a línea', () => _goToLine()),
            _menuItem('Seleccionar todo', () => _selectAll()),
          ]),
          _buildMenu('Ver', [
            _menuItem(_wordWrap ? 'Desactivar Ajuste' : 'Activar Ajuste', () => _toggleWordWrap()),
            _menuItem(_showLineNumbers ? 'Ocultar Números' : 'Mostrar Números', () => _toggleLineNumbers()),
            _menuItem('Zoom +', () => _adjustZoom(0.1)),
            _menuItem('Zoom -', () => _adjustZoom(-0.1)),
          ]),
          _buildMenu('Herramientas', [
            _menuItem(_terminalVisible ? 'Ocultar Terminal' : 'Mostrar Terminal', () => _toggleTerminal()),
            _menuItem('Ejecutar Código', () => _runCode()),
            _menuItem('Revisar Sintaxis', () => _checkSyntax()),
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
                  textAlign: _showLineNumbers ? TextAlign.right : TextAlign.left,
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
                      _fileName = _currentFilePath.isEmpty ? "Sin título*" : "$_fileName*";
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

  PopupMenuItem<dynamic> _menuItem(String label, VoidCallback onTap) {
    return PopupMenuItem<dynamic>(
      value: label,
      child: Text(label),
      onTap: onTap,
    );
  }

  PopupMenuButton<dynamic> _buildMenu(String title, List<PopupMenuItem<dynamic>> items) {
    return PopupMenuButton<dynamic>(
      tooltip: title,
      onSelected: (value) {
        // La acción ya se ejecuta en el onTap del MenuItem
      },
      itemBuilder: (context) => items,
    );
  }

  // --- FUNCIONES DE ARCHIVO REALES ---

  void _newFile() {
    setState(() {
      _controller.clear();
      _history.clear();
      _historyIndex = -1;
      _currentFilePath = "";
      _fileName = "Sin título";
    });
    _savePreferences();
    _showMsg("Nuevo archivo creado");
  }

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'dart', 'js', 'py', 'md', 'json', 'xml', 'html', 'css'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        
        setState(() {
          _controller.text = content;
          _currentFilePath = result.files.single.path!;
          _fileName = result.files.single.name;
          _history.clear();
          _history.add(content);
          _historyIndex = 0;
        });
        _showMsg("Archivo abierto: $_fileName");
      } else {
        _showMsg("No se seleccionó ningún archivo");
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
        setState(() {
          _fileName = _currentFilePath.split('/').last;
        });
        _showMsg("Archivo guardado exitosamente");
      } catch (e) {
        _showMsg("Error al guardar: $e");
      }
    }
  }

  Future<void> _saveFileAs() async {
    try {
      // En Android, guardamos en la carpeta Documents del usuario por defecto
      // ya que no tenemos un selector de "guardar como" nativo simple sin librerías pesadas
      Directory? directory = await getExternalStorageDirectory();
      String newPath = "";
      
      if (directory != null) {
        // Intentamos ir a la carpeta pública de Documentos
        List<String> paths = directory.path.split('/');
        if (paths.length > 1) {
          newPath = "/storage/emulated/0/Documents";
        } else {
          newPath = directory.path;
        }
      } else {
        // Fallback a directorio de la app si falla lo anterior
        directory = await getApplicationDocumentsDirectory();
        newPath = directory.path;
      }

      String fileName = "nota_${DateTime.now().millisecondsSinceEpoch}.txt";
      String fullPath = "$newPath/$fileName";
      
      File file = File(fullPath);
      await file.writeAsString(_controller.text);
      
      setState(() {
        _currentFilePath = fullPath;
        _fileName = fileName;
      });
      
      _showMsg("Guardado en: $fullPath");
    } catch (e) {
      _showMsg("Error al guardar como: $e");
    }
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

  void _showSearchDialog() {
    showDialog(
      context: context, 
      builder: (_) => AlertDialog(
        title: const Text("Buscar"),
        content: TextField(
          decoration: const InputDecoration(hintText: "Texto a buscar..."),
          onChanged: (val) {
            int index = _controller.text.indexOf(val);
            if (index != -1) {
              _controller.selection = TextSelection(baseOffset: index, extentOffset: index + val.length);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar"))
        ],
      )
    );
  }

  void _goToLine() {
    TextEditingController lineController = TextEditingController();
    showDialog(
      context: context, 
      builder: (_) => AlertDialog(
        title: const Text("Ir a Línea"),
        content: TextField(
          controller: lineController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Número de línea"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              int lineNum = int.tryParse(lineController.text) ?? 1;
              if (lineNum > 0 && lineNum <= _totalLines) {
                int pos = 0;
                List<String> lines = _controller.text.split('\n');
                for (int i = 0; i < lineNum - 1; i++) {
                  pos += lines[i].length + 1;
                }
                _controller.selection = TextSelection.fromPosition(TextPosition(offset: pos));
              }
              Navigator.pop(context);
            }, 
            child: const Text("Ir")
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar"))
        ],
      )
    );
  }

  void _selectAll() {
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    _showMsg("Todo seleccionado");
  }

  // --- FUNCIONES DE VISTA ---

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

  // --- HERRAMIENTAS ---

  void _toggleTerminal() {
    setState(() => _terminalVisible = !_terminalVisible);
  }

  void _runCode() {
    _showMsg("Simulando ejecución... (Requiere entorno específico)");
  }

  void _checkSyntax() {
    int openP = 0;
    int closeP = 0;
    
    // Contar paréntesis, llaves y corchetes
    openP = '({['.split('').fold(0, (sum, c) => sum + _controller.text.split(c).length - 1);
    closeP = ')}]'.split('').fold(0, (sum, c) => sum + _controller.text.split(c).length - 1);

    if (openP == closeP) {
      _showMsg("Sintaxis básica correcta (paréntesis balanceados)");
    } else {
      _showMsg("Error de sintaxis: Paréntesis/Simbolos no balanceados ($openP abiertos, $closeP cerrados)");
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2))
    );
  }
}
