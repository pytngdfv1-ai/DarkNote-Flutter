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
  bool _isReadOnly = false;
  bool _terminalVisible = false;
  
  // Variables de estado de archivo
  String? _currentFilePath;
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
        allowedExtensions: ['txt', 'md', 'dart', 'js', 'py', 'json', 'xml', 'html', 'css'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        
        setState(() {
          _controller.text = content;
          _currentFilePath = file.path;
          _fileName = result.files.single.name;
          _history.clear();
          _history.add(content);
          _historyIndex = 0;
        });
        _showMsg("Archivo abierto: $_fileName");
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
      return;
    }

    try {
      File file = File(_currentFilePath!);
      await file.writeAsString(_controller.text);
      _showMsg("Guardado exitosamente en: $_fileName");
    } catch (e) {
      _showMsg("Error al guardar: $e");
    }
  }

  Future<void> _saveFileAs() async {
    try {
      // Usar el selector nativo de Android para elegir ruta y nombre
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: "Guardar archivo como...",
        fileName: "nota_${DateTime.now().millisecondsSinceEpoch}.txt",
        fileType: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (outputPath != null) {
        File file = File(outputPath);
        await file.writeAsString(_controller.text);
        
        setState(() {
          _currentFilePath = outputPath;
          _fileName = outputPath.split('/').last;
        });
        
        _showMsg("Archivo guardado en: $_fileName");
      } else {
        _showMsg("Guardado cancelado");
      }
    } catch (e) {
      _showMsg("Error fatal al guardar: $e");
    }
  }

  // --- FUNCIONES DE EDICIÓN ---

  void _newFile() {
    setState(() {
      _controller.clear();
      _currentFilePath = null;
      _fileName = "Sin título";
      _history.clear();
      _historyIndex = -1;
    });
    _showMsg("Nuevo archivo creado");
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

  void _checkSyntax() {
    int openP = 0;
    int closeP = 0;
    
    // Contar paréntesis, llaves y corchetes
    for (int i = 0; i < _controller.text.length; i++) {
      String char = _controller.text[i];
      if ('({['.contains(char)) openP++;
      if (')}]'.contains(char)) closeP++;
    }

    if (openP == closeP) {
      _showMsg("✓ Sintaxis válida: Estructura balanceada.");
    } else {
      _showMsg("⚠ Error de sintaxis: Tienes $openP aperturas y $closeP cierres.");
    }
  }

  void _runCode() {
    _showMsg("Ejecutando simulación... (Requiere configuración de entorno)");
    setState(() => _terminalVisible = true);
  }

  void _toggleTerminal() {
    setState(() => _terminalVisible = !_terminalVisible);
  }

  void _selectAll() {
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    _showMsg("Todo seleccionado");
  }

  void _goToLine() {
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text("Ir a línea"),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: "Número de línea"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            TextButton(
              onPressed: () {
                int line = int.tryParse(ctrl.text) ?? 1;
                // Lógica simple para ir a línea
                List<String> lines = _controller.text.split('\n');
                if (line > lines.length) line = lines.length;
                int pos = 0;
                for(int i=0; i<line-1; i++) pos += lines[i].length + 1;
                
                _controller.selection = TextSelection(baseOffset: pos, extentOffset: pos);
                Navigator.pop(ctx);
              },
              child: const Text("Ir"),
            )
          ],
        );
      },
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
    setState(() {
      _zoomLevel = ((_zoomLevel + delta).clamp(0.5, 2.0));
    });
    _savePreferences();
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = 14.0 * _zoomLevel;

    return Scaffold(
      appBar: AppBar(
        title: Text(_fileName),
        actions: [
          _buildMenu('Archivo', [
            MenuItem('Nuevo', Icons.note_add, _newFile),
            MenuItem('Abrir', Icons.folder_open, _openFile),
            MenuItem('Guardar', Icons.save, _saveFile),
            MenuItem('Guardar como', Icons.save_as, _saveFileAs),
            const Divider(height: 1),
            MenuItem('Exportar PDF', Icons.picture_as_pdf, () => _showMsg("Próximamente")),
          ]),
          _buildMenu('Edición', [
            MenuItem('Deshacer', Icons.undo, _undo),
            MenuItem('Rehacer', Icons.redo, _redo),
            const Divider(height: 1),
            MenuItem('Buscar', Icons.search, () => _showMsg("Buscar: Próximamente")),
            MenuItem('Ir a línea', Icons.arrow_downward, _goToLine),
            MenuItem('Seleccionar todo', Icons.select_all, _selectAll),
          ]),
          _buildMenu('Ver', [
            MenuItem(_wordWrap ? 'Desactivar Ajuste' : 'Activar Ajuste', Icons.wrap_text, _toggleWordWrap),
            MenuItem(_showLineNumbers ? 'Ocultar Números' : 'Mostrar Números', Icons.format_list_numbered, _toggleLineNumbers),
            const Divider(height: 1),
            MenuItem('Zoom +', Icons.zoom_in, () => _adjustZoom(0.1)),
            MenuItem('Zoom -', Icons.zoom_out, () => _adjustZoom(-0.1)),
          ]),
          _buildMenu('Herramientas', [
            MenuItem(_terminalVisible ? 'Ocultar Terminal' : 'Mostrar Terminal', Icons.terminal, _toggleTerminal),
            MenuItem('Ejecutar Código', Icons.play_arrow, _runCode),
            MenuItem('Revisar Sintaxis', Icons.check_circle_outline, _checkSyntax),
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
                    width: 45,
                    child: Container(
                      color: const Color(0xFF252526),
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 5, top: 8),
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
                      const Text("TERMINAL", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), onPressed: _toggleTerminal)
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        "> Sistema listo...\n> Esperando comando...\n",
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
            Text('Ln $_currentLine, Col $_currentColumn', style: const TextStyle(fontSize: 11, color: Colors.white)),
            Text('Total: $_totalLines', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            Text('Chars: ${_controller.text.length}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            Text(_wordWrap ? 'Wrap: ON' : 'Wrap: OFF', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            Text('Zoom: ${(_zoomLevel * 100).toInt()}%', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            Text(_encoding, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  PopupMenuButton<String> _buildMenu(String title, List<MenuItem> items) {
    return PopupMenuButton<String>(
      tooltip: title,
      icon: Icon(items.first.icon, color: Colors.white), // Usa el icono del primer item como referencia visual o podrías personalizarlo
      onSelected: (value) {
        final item = items.firstWhere((i) => i.value == value, orElse: () => MenuItem('', Icons.error, () {}));
        item.onTap();
      },
      itemBuilder: (context) => items.map((item) {
        if (item is DividerItem) {
          return const PopupMenuDivider();
        }
        return PopupMenuItem<String>(
          value: item.value,
          child: Row(
            children: [
              Icon(item.icon, size: 20, color: Colors.blueGrey),
              const SizedBox(width: 12),
              Text(item.label),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// Clases auxiliares para el menú
abstract class MenuEntry {
  final String label;
  final IconData icon;
  MenuEntry(this.label, this.icon);
}

class MenuItem extends MenuEntry {
  final String value;
  final VoidCallback onTap;
  MenuItem(String label, IconData icon, this.onTap) : super(label, icon), value = label;
}

class DividerItem extends MenuEntry {
  DividerItem() : super('', Icons.error);
}
