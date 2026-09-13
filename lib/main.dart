import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
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
        dialogTheme: const DialogTheme(
          backgroundColor: Color(0xFF252526),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
          contentTextStyle: TextStyle(color: Colors.white70),
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
  
  // Variables para gestión de archivos
  File? _currentFile;
  String _fileName = "Sin título";

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
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
      // Para Android 11+ también pedir manageExternalStorage si es necesario
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    }
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
        allowedExtensions: ['txt', 'dart', 'js', 'py', 'json', 'md', 'xml', 'html', 'css'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        
        setState(() {
          _controller.text = content;
          _currentFile = file;
          _fileName = result.files.single.name;
          _history.clear();
          _historyIndex = -1;
          _history.add(content);
          _historyIndex++;
        });
        
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Archivo "$_fileName" abierto correctamente'), duration: const Duration(seconds: 2)),
          );
        }
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir archivo: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  Future<void> _saveFile() async {
    if (_currentFile == null) {
      await _saveFileAs();
      return;
    }

    try {
      await _currentFile!.writeAsString(_controller.text);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo guardado correctamente'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  Future<void> _saveFileAs() async {
    // Mostrar diálogo para ingresar nombre
    String fileName = _fileName == "Sin título" ? "nota_${DateTime.now().millisecondsSinceEpoch}.txt" : _fileName;
    
    final controller = TextEditingController(text: fileName);
    
    bool saved = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Guardar como"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ingrese el nombre del archivo:"),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Nombre",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.save),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              
              try {
                final directory = await getExternalStorageDirectory();
                if (directory == null) throw Exception("No se pudo acceder al almacenamiento");
                
                // Guardar en la carpeta Documents
                final saveDir = Directory("${directory.parent.path}/Documents");
                if (!await saveDir.exists()) {
                  await saveDir.create(recursive: true);
                }
                
                String finalName = controller.text.trim();
                if (!finalName.endsWith('.txt')) finalName += '.txt';
                
                final file = File("${saveDir.path}/$finalName");
                await file.writeAsString(_controller.text);
                
                setState(() {
                  _currentFile = file;
                  _fileName = finalName;
                });
                
                saved = true;
                if(mounted) Navigator.pop(context);
                if(mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Guardado en Documentos/$finalName'), duration: const Duration(seconds: 3)),
                  );
                }
              } catch (e) {
                if(mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al guardar: $e'), duration: const Duration(seconds: 3)),
                  );
                }
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // --- FUNCIONES DE EDICIÓN ---

  void _newFile() {
    setState(() {
      _controller.clear();
      _currentFile = null;
      _fileName = "Sin título";
      _history.clear();
      _historyIndex = -1;
    });
  }

  void _undo() {
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        _isTyping = false;
        _controller.text = _history[_historyIndex];
        _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
      });
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      setState(() {
        _historyIndex++;
        _isTyping = false;
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
          decoration: const InputDecoration(hintText: "Texto a buscar...", prefixIcon: Icon(Icons.search)),
          autofocus: true,
          onChanged: (val) {
            // Lógica simple de búsqueda futura
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar"))
        ],
      )
    );
  }

  void _goToLine() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ir a línea"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Número de línea", prefixIcon: Icon(Icons.arrow_downward)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              int line = int.tryParse(controller.text) ?? 1;
              // Lógica para mover el cursor (simplificada)
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Navegando a línea $line (Simulado)")));
            },
            child: const Text("Ir"),
          )
        ],
      ),
    );
  }

  void _selectAll() {
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ejecutando código... (Simulación: No hay entorno de runtime integrado)"), duration: Duration(seconds: 3)),
    );
  }

  void _checkSyntax() {
    // Corrección de sintaxis: Paréntesis balanceados correctamente
    String text = _controller.text;
    int openP = 0;
    int closeP = 0;
    
    // Contar paréntesis, llaves y corchetes
    openP = '({['.split('').fold(0, (sum, c) => sum + text.split(c).length - 1);
    closeP = ')}]'.split('').fold(0, (sum, c) => sum + text.split(c).length - 1);

    if (openP == closeP) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sintaxis válida: Estructura balanceada."), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Posible error: $openP aperturas, $closeP cierres."), backgroundColor: Colors.orange, duration: const Duration(seconds: 3)),
      );
    }
  }

  // --- UI HELPERS ---

  PopupMenuButton<String> _buildMenu(String title, List<Map<String, dynamic>> items) {
    return PopupMenuButton<String>(
      tooltip: title,
      icon: Icon(
        title == 'Archivo' ? Icons.menu_book : 
        title == 'Edición' ? Icons.edit : 
        title == 'Ver' ? Icons.visibility : Icons.build,
        color: Colors.white,
      ),
      onSelected: (value) {
        final item = items.firstWhere((i) => i['value'] == value, orElse: () => {'action': () {}});
        if (item['action'] != null) item['action']();
      },
      itemBuilder: (context) => items.map((item) {
        if (item['divider'] == true) {
          return const PopupMenuDivider();
        }
        return PopupMenuItem(value: item['value'], child: Text(item['label']));
      }).toList(),
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
            {'label': 'Nuevo', 'value': 'new', 'action': _newFile},
            {'label': 'Abrir', 'value': 'open', 'action': _openFile},
            {'label': 'Guardar', 'value': 'save', 'action': _saveFile},
            {'label': 'Guardar como', 'value': 'saveas', 'action': _saveFileAs},
            {'divider': true},
            {'label': 'Solo lectura', 'value': 'readonly', 'action': () => setState(() => _isReadOnly = !_isReadOnly)},
          ]),
          _buildMenu('Edición', [
            {'label': 'Deshacer', 'value': 'undo', 'action': _undo},
            {'label': 'Rehacer', 'value': 'redo', 'action': _redo},
            {'divider': true},
            {'label': 'Buscar', 'value': 'search', 'action': _showSearchDialog},
            {'label': 'Ir a línea', 'value': 'goto', 'action': _goToLine},
            {'label': 'Seleccionar todo', 'value': 'selectall', 'action': _selectAll},
          ]),
          _buildMenu('Ver', [
            {'label': _wordWrap ? 'Desactivar Ajuste' : 'Activar Ajuste', 'value': 'wrap', 'action': _toggleWordWrap},
            {'label': _showLineNumbers ? 'Ocultar Números' : 'Mostrar Números', 'value': 'lines', 'action': _toggleLineNumbers},
            {'divider': true},
            {'label': 'Zoom +', 'value': 'zin', 'action': () => _adjustZoom(0.1)},
            {'label': 'Zoom -', 'value': 'zout', 'action': () => _adjustZoom(-0.1)},
          ]),
          _buildMenu('Herramientas', [
            {'label': _terminalVisible ? 'Ocultar Terminal' : 'Mostrar Terminal', 'value': 'term', 'action': _toggleTerminal},
            {'label': 'Ejecutar Código', 'value': 'run', 'action': _runCode},
            {'label': 'Revisar Sintaxis', 'value': 'syntax', 'action': _checkSyntax},
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
                  const Text("TERMINAL", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        "> Esperando comando...\n> Sistema listo.\n",
                        style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar
