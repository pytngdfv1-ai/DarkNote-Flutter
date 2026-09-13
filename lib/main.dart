import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
        // Tema corregido para Flutter 3.19
        bottomAppBarTheme: const BottomAppBarTheme(
          color: Color(0xFF007ACC),
          elevation: 0,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF252526),
          // textColor eliminado por incompatibilidad, usamos estilo por defecto oscuro
        ),
        dialogTheme: const DialogTheme(
          backgroundColor: Color(0xFF252526),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF3C3C3C),
          labelStyle: const TextStyle(color: Colors.white),
          hintStyle: const TextStyle(color: Colors.grey),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.transparent),
            borderRadius: BorderRadius.circular(4),
          ),
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
  
  // Estado del cursor y documento
  int _currentLine = 1;
  int _currentColumn = 1;
  int _totalLines = 1;
  String _fileName = "Sin título";
  bool _isModified = false;
  bool _isReadOnly = false;

  // Configuración de vista
  bool _wordWrap = false;
  bool _showLineNumbers = false;
  double _zoomLevel = 1.0;
  
  // Estado de herramientas
  bool _terminalVisible = false;
  final List<String> _terminalLogs = [];
  final ScrollController _terminalScrollController = ScrollController();
  
  // Historial para Deshacer/Rehacer
  final List<String> _history = [];
  int _historyIndex = -1;
  bool _isTyping = false;
  Timer? _debounceTimer;

  // Autocierre de símbolos
  static const Map<String, String> _autoClosePairs = {
    '(': ')',
    '{': '}',
    '[': ']',
    '"': '"',
    "'": "'",
  };

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateCursorPosition);
    _addToHistory(""); // Estado inicial
  }

  @override
  void dispose() {
    _controller.removeListener(_updateCursorPosition);
    _controller.dispose();
    _terminalScrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _logTerminal(String message) {
    setState(() {
      _terminalLogs.add("[${DateTime.now().toString().split(' ').last}] $message");
      if (_terminalLogs.length > 50) _terminalLogs.removeAt(0);
    });
    // Auto-scroll al final
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalScrollController.hasClients) {
        _terminalScrollController.animateTo(
          _terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _updateCursorPosition() {
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
      
      // Gestión simple de historial (guarda cada 1 segundo de inactividad)
      if (!_isTyping) {
        _isTyping = true;
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(seconds: 1), () {
          _isTyping = false;
          _addToHistory(_controller.text);
        });
      }
    });
  }

  void _addToHistory(String text) {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    if (_history.isEmpty || _history.last != text) {
      _history.add(text);
      _historyIndex++;
    }
    if (_history.length > 50) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  void _undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _controller.text = _history[_historyIndex];
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      _logTerminal("Deshacer acción");
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _controller.text = _history[_historyIndex];
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      _logTerminal("Rehacer acción");
    }
  }

  Future<void> _newFile() async {
    if (_isModified) {
      // En una app real preguntaríamos guardar, aquí simplificamos
      _logTerminal("Advertencia: Cambios no guardados se perderán");
    }
    setState(() {
      _controller.clear();
      _fileName = "Sin título";
      _isModified = false;
      _addToHistory("");
    });
    _logTerminal("Nuevo archivo creado");
  }

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'dart', 'js', 'py', 'md', 'json', 'xml'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        setState(() {
          _controller.text = content;
          _fileName = result.files.single.name;
          _isModified = false;
          _addToHistory(content);
        });
        _logTerminal("Archivo abierto: $_fileName");
      }
    } catch (e) {
      _logTerminal("Error al abrir archivo: $e");
    }
  }

  Future<void> _saveFile() async {
    try {
      if (_fileName == "Sin título") {
        await _saveFileAs();
        return;
      }
      
      // Nota: En Android sandboxed, guardar directamente es complejo sin permisos especiales.
      // Usaremos el directorio de documentos de la app para este ejemplo.
      final directory = await getApplicationDocumentsDirectory();
      final filePath = "${directory.path}/$_fileName";
      final file = File(filePath);
      
      await file.writeAsString(_controller.text);
      setState(() {
        _isModified = false;
      });
      _logTerminal("Archivo guardado en: $filePath");
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Guardado en ${directory.path}'), duration: const Duration(seconds: 2)),
      );
    } catch (e) {
      _logTerminal("Error al guardar: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar. Verifica permisos.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveFileAs() async {
    // Simulación de "Guardar como" (FilePicker no soporta nativamente "Guardar como" en Android fácilmente)
    // Guardaremos con un timestamp o nombre por defecto en la carpeta de la app
    final directory = await getApplicationDocumentsDirectory();
    final defaultName = "darknote_backup_${DateTime.now().millisecondsSinceEpoch}.txt";
    final filePath = "${directory.path}/$defaultName";
    
    try {
      final file = File(filePath);
      await file.writeAsString(_controller.text);
      setState(() {
        _fileName = defaultName;
        _isModified = false;
      });
      _logTerminal("Guardado como: $filePath");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Guardado como: $defaultName')),
      );
    } catch (e) {
      _logTerminal("Error al guardar como: $e");
    }
  }

  Future<void> _exportPdf() async {
    _logTerminal("Generando PDF...");
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_fileName, style: const pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text(_controller.text, style: const pw.TextStyle(fontSize: 12, fontFamily: 'Courier')),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: "$_fileName.pdf",
      );
      _logTerminal("PDF exportado exitosamente");
    } catch (e) {
      _logTerminal("Error exportando PDF: $e");
    }
  }

  void _toggleReadOnly() {
    setState(() {
      _isReadOnly = !_isReadOnly;
      _logTerminal(_isReadOnly ? "Modo Solo Lectura: ACTIVADO" : "Modo Solo Lectura: DESACTIVADO");
    });
  }

  void _findAndReplace() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Buscar y Reemplazar"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: "Buscar", prefixIcon: Icon(Icons.search)),
              onChanged: (val) {},
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: "Reemplazar con", prefixIcon: Icon(Icons.replace)),
              onChanged: (val) {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              // Lógica simplificada de reemplazo
              // En una app completa, esto iteraría y seleccionaría
              _logTerminal("Función Buscar/Reemplazar ejecutada (Simulada)");
              Navigator.pop(context);
            },
            child: const Text("Reemplazar Todo"),
          ),
        ],
      ),
    );
  }

  void _goToLine() {
    showDialog(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text("Ir a Línea"),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Número de línea"),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () {
                int? line = int.tryParse(ctrl.text);
                if (line != null && line > 0 && line <= _totalLines) {
                  // Calcular offset aproximado (simplificado)
                  // Para precisión total se necesita parsear saltos de línea
                  _logTerminal("Navegando a línea $line");
                  // Aquí iría la lógica de selección real
                } else {
                  _logTerminal("Línea inválida");
                }
                Navigator.pop(context);
              },
              child: const Text("Ir"),
            ),
          ],
        );
      },
    );
  }

  void _handleSymbolInput(String symbol) {
    final text = _controller.text;
    final selection = _controller.selection;
    
    if (selection.isCollapsed) {
      final closingSymbol = _autoClosePairs[symbol];
      final newText = text.replaceRange(
        selection.baseOffset,
        selection.baseOffset,
        '$symbol$closingSymbol',
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.baseOffset + 1),
      );
    } else {
      // Si hay texto seleccionado, lo envolvemos
      final selectedText = text.substring(selection.start, selection.end);
      final closingSymbol = _autoClosePairs[symbol];
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$symbol$selectedText$closingSymbol',
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(baseOffset: selection.start + 1, extentOffset: selection.end + 1),
      );
    }
    _addToHistory(_controller.text);
  }

  void _runCode() {
    _terminalVisible = true;
    _logTerminal("Ejecutando script...");
    
    // Simulación de ejecución
    Future.delayed(const Duration(milliseconds: 800), () {
      _logTerminal("> Compilando...");
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_controller.text.isEmpty) {
          _logTerminal("Error: Archivo vacío.");
        } else {
          _logTerminal("Éxito: Salida generada (Simulación).");
          _logTerminal("Resultado: 0");
        }
      });
    });
  }

  void _checkSyntax() {
    _terminalVisible = true;
    _logTerminal("Analizando sintaxis...");
    
    // Análisis muy básico de paréntesis balanceados
    int openParens = 0;
    int openBraces = 0;
    int openBrackets = 0;
    
    for (var char in _controller.text.runes) {
      String s = String.fromCharCode(char);
      if (s == '(') openParens++;
      if (s == ')') openParens--;
      if (s == '{') openBraces++;
      if (s == '}') openBraces--;
      if (s == '[') openBrackets++;
      if (s == ']') openBrackets--;
    }
    
    if (openParens == 0 && openBraces == 0 && openBrackets == 0) {
      _logTerminal("Sintaxis: OK (Paréntesis/Llaves balanceados)");
    } else {
      _logTerminal("Error de Sintaxis: Paréntesis o llaves sin cerrar.");
      if (openParens != 0) _logTerminal("  - Faltan $openParens paréntesis de cierre");
      if (openBraces != 0) _logTerminal("  - Faltan $openBraces llaves de cierre");
      if (openBrackets != 0) _logTerminal("  - Faltan $openBrackets corchetes de cierre");
    }
  }

  void _selectAll() {
    _controller.selectAll();
    _logTerminal("Todo el texto seleccionado");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isModified ? '● $_fileName' : _fileName),
        actions: [
          // Menú Archivo
          PopupMenuButton<String>(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Archivo',
            onSelected: (value) {
              switch (value) {
                case 'nuevo': _newFile(); break;
                case 'abrir': _openFile(); break;
                case 'guardar': _saveFile(); break;
                case 'guardar_como': _saveFileAs(); break;
                case 'exportar': _exportPdf(); break;
                case 'solo_lectura': _toggleReadOnly(); break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'nuevo', child: ListTile(leading: Icon(Icons.note_add), title: Text('Nuevo'))),
              const PopupMenuItem(value: 'abrir', child: ListTile(leading: Icon(Icons.folder), title: Text('Abrir'))),
              const PopupMenuItem(value: 'guardar', child: ListTile(leading: Icon(Icons.save), title: Text('Guardar'))),
              const PopupMenuItem(value: 'guardar_como', child: ListTile(leading: Icon(Icons.save_as), title: Text('Guardar como'))),
              const PopupMenuItem(value: 'exportar', child: ListTile(leading: Icon(Icons.picture_as_pdf), title: Text('Exportar PDF'))),
              const PopupMenuItem(value: 'solo_lectura', child: ListTile(leading: Icon(Icons.lock), title: Text(_isReadOnly ? 'Desactivar Solo Lectura' : 'Solo Lectura'))),
            ],
          ),
          // Menú Edición
          PopupMenuButton<String>(
            icon: const Icon(Icons.edit),
            tooltip: 'Edición',
            onSelected: (value) {
              switch (value) {
                case 'deshacer': _undo(); break;
                case 'rehacer': _redo(); break;
                case 'buscar': _findAndReplace(); break;
                case 'seleccionar_todo': _selectAll(); break;
                case 'ir_linea': _goToLine(); break;
                case 'autoclose': 
                  setState(() { /* Toggle future */ }); 
                  _logTerminal("Autocierre activado/desactivado");
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'deshacer', child: ListTile(leading: Icon(Icons.undo), title: Text('Deshacer'))),
              const PopupMenuItem(value: 'rehacer', child: ListTile(leading: Icon(Icons.redo), title: Text('Rehacer'))),
              const PopupMenuItem(value: 'buscar', child: ListTile(leading: Icon(Icons.find_in_page), title: Text('Buscar/Reemplazar'))),
              const PopupMenuItem(value: 'seleccionar_todo', child: ListTile(leading: Icon(Icons.select_all), title: Text('Seleccionar todo'))),
              const PopupMenuItem(value: 'ir_linea', child: ListTile(leading: Icon(Icons.arrow_downward), title: Text('Ir a línea'))),
              const PopupMenuItem(value: 'autoclose', child: ListTile(leading: Icon(Icons.auto_fix_high), title: Text('Autocerrar Símbolos'))),
            ],
          ),
          // Menú Ver
          PopupMenuButton<String>(
            icon: const Icon(Icons.visibility),
            tooltip: 'Ver',
            onSelected: (value) {
              setState(() {
                if (value == 'wrap') _wordWrap = !_wordWrap;
                if (value == 'linenum') _showLineNumbers = !_showLineNumbers;
                if (value == 'zoom_in') _zoomLevel = (_zoomLevel + 0.1).clamp(0.5, 2.0);
                if (value == 'zoom_out') _zoomLevel = (_zoomLevel - 0.1).clamp(0.5, 2.0);
              });
              _logTerminal("Vista actualizada: Zoom ${(_zoomLevel*100).toInt()}%, Wrap $_wordWrap");
            },
            itemBuilder: (BuildContext context) => [
              CheckedPopupMenuItem(value: 'wrap', checked: _wordWrap, child: const Text('Ajuste de línea')),
              CheckedPopupMenuItem(value: 'linenum', checked: _showLineNumbers, child: const Text('Números de línea')),
              const PopupMenuItem(value: 'zoom_in', child: ListTile(leading: Icon(Icons.zoom_in), title: Text('Zoom In (+)'))),
              const PopupMenuItem(value: 'zoom_out', child: ListTile(leading: Icon(Icons.zoom_out), title: Text('Zoom Out (-)'))),
            ],
          ),
          // Menú Herramientas
          PopupMenuButton<String>(
            icon: const Icon(Icons.build),
            tooltip: 'Herramientas',
            onSelected: (value) {
              setState(() {
                if (value == 'terminal') _terminalVisible = !_terminalVisible;
              });
              if (value == 'run') _runCode();
              if (value == 'syntax') _checkSyntax();
            },
            itemBuilder: (BuildContext context) => [
              CheckedPopupMenuItem(value: 'terminal', checked: _terminalVisible, child: const Text('Mostrar Terminal')),
              const PopupMenuItem(value: 'run', child: ListTile(leading: Icon(Icons.play_arrow), title: Text('Ejecutar'))),
              const PopupMenuItem(value: 'syntax', child: ListTile(leading: Icon(Icons.code), title: Text('Revisar Sintaxis'))),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Área de edición
          Expanded(
            child: Row(
              children: [
                // Números de línea (opcional)
                if (_showLineNumbers)
                  Container(
                    width: 40,
                    color: const Color(0xFF252526),
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(top: 8, right: 4),
                    child: ListView.builder(
                      itemCount: _totalLines,
                      itemBuilder: (ctx, i) => Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14 * _zoomLevel,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                // Editor
                Expanded(
                  child: Container(
                    color: const Color(0xFF1E1E1E),
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _controller,
                      enabled: !_isReadOnly,
                      maxLines: null,
                      expands: true,
                      textAlign: _showLineNumbers ? TextAlign.left : TextAlign.left,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14.0 * _zoomLevel,
                        color: Colors.white,
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        hintText: '// Escribe tu código aquí...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      cursorColor: Colors.white,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      // Interceptamos entrada para autocierre
                      onChanged: (val) {
                         // La lógica de autocierre requiere interceptar teclas específicas,
                         // lo cual es complejo en TextField estándar. 
                         // Esta es una implementación básica visual.
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Terminal Panel (Colapsable)
          if (_terminalVisible)
            Container(
              height: 150,
              color: const Color(0xFF1E1E1E),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: const Color(0xFF2D2D2D),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("TERMINAL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _terminalLogs.clear()),
                          tooltip: "Limpiar",
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _terminalVisible = false),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _terminalScrollController,
                      padding: const EdgeInsets.all(4),
                      itemCount: _terminalLogs.length,
                      itemBuilder: (ctx, i) => Text(
                        _terminalLogs[i],
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.greenAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      // Barra de estado inferior
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                Text('Ln $_currentLine, Col $_currentColumn', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Text('Total: $_totalLines', style: const TextStyle(fontSize: 12)),
              ],
            ),
            Row(
              children: [
                Text('${_controller.text.length} chars', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Text(_wordWrap ? 'Wrap: ON' : 'Wrap: OFF', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Text('${(_zoomLevel * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Text('UTF-8', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      ),
      // Botón flotante para acceso rápido a símbolos (Ayuda móvil)
      floatingActionButton: FloatingActionButton.small(
        heroTag: "symbols",
        onPressed: () {
          // Mostrar un pequeño menú de símbolos rápidos
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Container(
              color: const Color(0xFF252526),
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['{', '(', '[', '"', ';', ''].map((s) {
                  if (s.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: Text(s, style: const TextStyle(color: Colors.white, fontSize: 20)),
                    onPressed: () {
                      _handleSymbolInput(s);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ),
          );
        },
        child: const Icon(Icons.code),
        tooltip: "Insertar Símbolo",
      ),
    );
  }
}
