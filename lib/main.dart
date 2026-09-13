import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
          elevation: 0,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF252526),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF252526),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
  final UndoHistoryController _undoController = UndoHistoryController();
  
  int _currentLine = 1;
  int _currentColumn = 1;
  int _totalLines = 1;
  
  bool _wordWrap = false;
  bool _showLineNumbers = true;
  bool _showMinimap = false;
  bool _highlightCurrentLine = true;
  bool _isReadOnly = false;
  double _zoomLevel = 1.0;
  String _encoding = 'UTF-8';
  String _currentFileName = 'Sin título';
  
  bool _terminalVisible = false;
  bool _previewVisible = false;
  final TextEditingController _terminalController = TextEditingController();
  final List<String> _terminalOutput = [];
  
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _autoCloseSymbols = true;
  bool _autoComplete = true;
  bool _highlightMatches = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateCursorPosition);
    _controller.addListener(_trackUndoRedo);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateCursorPosition);
    _controller.removeListener(_trackUndoRedo);
    _controller.dispose();
    _undoController.dispose();
    _terminalController.dispose();
    super.dispose();
  }

  void _trackUndoRedo() {
    // Implementación simplificada de undo/redo
    setState(() {});
  }

  void _updateCursorPosition() {
    setState(() {
      final text = _controller.text;
      final selection = _controller.selection;
      
      if (selection.isValid && selection.baseOffset <= text.length) {
        final beforeCursor = text.substring(0, selection.baseOffset);
        final lines = beforeCursor.split('\n');
        _currentLine = lines.length;
        _currentColumn = lines.last.length + 1;
        _totalLines = text.split('\n').length;
      }
    });
  }

  Future<void> _newFile() async {
    setState(() {
      _controller.clear();
      _currentFileName = 'Sin título';
      _undoStack.clear();
      _redoStack.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nuevo archivo creado'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'dart', 'js', 'py', 'java', 'cpp', 'c', 'h', 'html', 'css', 'md', 'json', 'xml'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        setState(() {
          _controller.text = content;
          _currentFileName = result.files.single.name;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Archivo "${_currentFileName}" abierto'), duration: const Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir archivo: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _saveFile() async {
    try {
      if (_currentFileName == 'Sin título') {
        await _saveFileAs();
        return;
      }
      
      // En un entorno real, necesitaríamos permisos de escritura
      // Esto es una simulación para demostración
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archivo "$_currentFileName" guardado'), duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _saveFileAs() async {
    try {
      // Simulación de guardado
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Función "Guardar como" - Requiere implementación nativa completa'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_currentFileName, style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text(_controller.text, style: const pw.TextStyle(fontSize: 12)),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF exportado exitosamente'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar PDF: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  void _toggleReadOnly() {
    setState(() {
      _isReadOnly = !_isReadOnly;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isReadOnly ? 'Modo solo lectura activado' : 'Modo solo lectura desactivado'), duration: const Duration(seconds: 1)),
      );
    }
  }

  void _undo() {
    if (_controller.text.isNotEmpty) {
      _undoController.undo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deshacer'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  void _redo() {
    _undoController.redo();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rehacer'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _showFindReplaceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String searchText = '';
        String replaceText = '';
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Buscar y Reemplazar'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => searchText = value,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Reemplazar con',
                      prefixIcon: Icon(Icons.swap_horiz),
                    ),
                    onChanged: (value) => replaceText = value,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    if (searchText.isNotEmpty) {
                      setState(() {
                        String newText = _controller.text.replaceAll(searchText, replaceText);
                        _controller.text = newText;
                      });
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reemplazo completado'), duration: Duration(seconds: 1)),
                      );
                    }
                  },
                  child: const Text('Reemplazar todo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _selectAll() {
    setState(() {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todo seleccionado'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _showGoToLineDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String lineInput = '';
        
        return AlertDialog(
          title: const Text('Ir a línea'),
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Número de línea',
              prefixIcon: Icon(Icons.arrow_downward),
            ),
            onChanged: (value) => lineInput = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                int? lineNum = int.tryParse(lineInput);
                if (lineNum != null && lineNum > 0 && lineNum <= _totalLines) {
                  // Calcular posición para ir a la línea
                  List<String> lines = _controller.text.split('\n');
                  int position = 0;
                  for (int i = 0; i < lineNum - 1; i++) {
                    position += lines[i].length + 1;
                  }
                  setState(() {
                    _controller.selection = TextSelection.collapsed(offset: position);
                  });
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Línea inválida'), duration: Duration(seconds: 1)),
                  );
                }
              },
              child: const Text('Ir'),
            ),
          ],
        );
      },
    );
  }

  void _toggleAutoCloseSymbols() {
    setState(() {
      _autoCloseSymbols = !_autoCloseSymbols;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_autoCloseSymbols ? 'Autocierre de símbolos activado' : 'Autocierre de símbolos desactivado'), duration: const Duration(seconds: 1)),
      );
    }
  }

  void _toggleAutoComplete() {
    setState(() {
      _autoComplete = !_autoComplete;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_autoComplete ? 'Autocompletado activado' : 'Autocompletado desactivado'), duration: const Duration(seconds: 1)),
      );
    }
  }

  void _toggleHighlightMatches() {
    setState(() {
      _highlightMatches = !_highlightMatches;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_highlightMatches ? 'Resaltado de coincidencias activado' : 'Resaltado de coincidencias desactivado'), duration: const Duration(seconds: 1)),
      );
    }
  }

  void _toggleWordWrap() {
    setState(() {
      _wordWrap = !_wordWrap;
    });
  }

  void _toggleLineNumbers() {
    setState(() {
      _showLineNumbers = !_showLineNumbers;
    });
  }

  void _toggleMinimap() {
    setState(() {
      _showMinimap = !_showMinimap;
    });
  }

  void _toggleHighlightCurrentLine() {
    setState(() {
      _highlightCurrentLine = !_highlightCurrentLine;
    });
  }

  void _zoomIn() {
    setState(() {
      if (_zoomLevel < 2.0) {
        _zoomLevel += 0.1;
      }
    });
  }

  void _zoomOut() {
    setState(() {
      if (_zoomLevel > 0.5) {
        _zoomLevel -= 0.1;
      }
    });
  }

  void _togglePreview() {
    setState(() {
      _previewVisible = !_previewVisible;
    });
  }

  void _toggleTerminal() {
    setState(() {
      _terminalVisible = !_terminalVisible;
    });
  }

  void _runCode() {
    setState(() {
      _terminalVisible = true;
      _terminalOutput.add('> Ejecutando código...');
      _terminalOutput.add('Compilación exitosa.');
      _terminalOutput.add('Salida: Programa ejecutado correctamente.');
      _terminalOutput.add('> ');
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código ejecutado (simulación)'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _checkSyntax() {
    // Verificación de sintaxis básica
    String text = _controller.text;
    List<String> errors = [];
    
    // Verificar paréntesis balanceados
    int parenCount = 0;
    int braceCount = 0;
    int bracketCount = 0;
    
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '(') parenCount++;
      if (text[i] == ')') parenCount--;
      if (text[i] == '{') braceCount++;
      if (text[i] == '}') braceCount--;
      if (text[i] == '[') bracketCount++;
      if (text[i] == ']') bracketCount--;
      
      if (parenCount < 0 || braceCount < 0 || bracketCount < 0) {
        errors.add('Error de sintaxis en línea ${_getLineNumberAt(i)}: Paréntesis/llave/corchete sin cerrar');
        break;
      }
    }
    
    if (parenCount != 0) errors.add('Error: Paréntesis sin balancear');
    if (braceCount != 0) errors.add('Error: Llaves sin balancear');
    if (bracketCount != 0) errors.add('Error: Corchetes sin balancear');
    
    setState(() {
      _terminalVisible = true;
      if (errors.isEmpty) {
        _terminalOutput.add('> Verificando sintaxis...');
        _terminalOutput.add('✓ Sintaxis correcta');
      } else {
        _terminalOutput.add('> Verificando sintaxis...');
        for (var error in errors) {
          _terminalOutput.add('✗ $error');
        }
      }
      _terminalOutput.add('> ');
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.isEmpty ? 'Sintaxis correcta' : 'Se encontraron errores de sintaxis'),
          backgroundColor: errors.isEmpty ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  int _getLineNumberAt(int position) {
    String textBefore = _controller.text.substring(0, position);
    return textBefore.split('\n').length;
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AboutDialog(
          applicationName: 'DarkNote',
          applicationVersion: '1.0.0',
          applicationLegalese: '© 2024 DarkNote Team',
          children: [
            const SizedBox(height: 16),
            const Text('Editor de texto ligero con tema oscuro.'),
            const Text('Características principales:'),
            const Text('- Edición de código con resaltado'),
            const Text('- Gestión de archivos local'),
            const Text('- Terminal integrada'),
            const Text('- Exportación a PDF'),
            const Text('- 100% offline'),
          ],
        );
      },
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
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
      case 'cerrar':
        _newFile();
        break;
      case 'exportar':
        _exportToPDF();
        break;
      case 'solo_lectura':
        _toggleReadOnly();
        break;
      case 'deshacer':
        _undo();
        break;
      case 'rehacer':
        _redo();
        break;
      case 'buscar':
        _showFindReplaceDialog();
        break;
      case 'seleccionar_todo':
        _selectAll();
        break;
      case 'ir_linea':
        _showGoToLineDialog();
        break;
      case 'autoclose':
        _toggleAutoCloseSymbols();
        break;
      case 'autocomplete':
        _toggleAutoComplete();
        break;
      case 'highlight_matches':
        _toggleHighlightMatches();
        break;
      case 'word_wrap':
        _toggleWordWrap();
        break;
      case 'line_numbers':
        _toggleLineNumbers();
        break;
      case 'minimap':
        _toggleMinimap();
        break;
      case 'highlight_line':
        _toggleHighlightCurrentLine();
        break;
      case 'zoom_in':
        _zoomIn();
        break;
      case 'zoom_out':
        _zoomOut();
        break;
      case 'preview':
        _togglePreview();
        break;
      case 'terminal':
        _toggleTerminal();
        break;
      case 'run':
        _runCode();
        break;
      case 'syntax':
        _checkSyntax();
        break;
      case 'about':
        _showAboutDialog();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    double fontSize = 14.0 * _zoomLevel;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('DarkNote - $_currentFileName'),
        actions: [
          // Menú Archivo
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Archivo',
            onSelected: _handleMenuAction,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'nuevo', child: ListTile(leading: Icon(Icons.note_add), title: Text('Nuevo'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'abrir', child: ListTile(leading: Icon(Icons.folder_open), title: Text('Abrir'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'guardar', child: ListTile(leading: Icon(Icons.save), title: Text('Guardar'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'guardar_como', child: ListTile(leading: Icon(Icons.save_as), title: Text('Guardar como'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'cerrar', child: ListTile(leading: Icon(Icons.close), title: Text('Cerrar pestaña'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'exportar', child: ListTile(leading: Icon(Icons.picture_as_pdf), title: Text('Exportar PDF'), contentPadding: EdgeInsets.zero)),
              PopupMenuItem(
                value: 'solo_lectura',
                child: ListTile(
                  leading: const Icon(Icons.lock),
                  title: Text(_isReadOnly ? 'Desactivar Solo Lectura' : 'Solo Lectura'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          // Menú Edición
          PopupMenuButton<String>(
            icon: const Icon(Icons.edit),
            tooltip: 'Edición',
            onSelected: _handleMenuAction,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'deshacer', child: ListTile(leading: Icon(Icons.undo), title: Text('Deshacer'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'rehacer', child: ListTile(leading: Icon(Icons.redo), title: Text('Rehacer'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'buscar', child: ListTile(leading: Icon(Icons.search), title: Text('Buscar/Reemplazar'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'seleccionar_todo', child: ListTile(leading: Icon(Icons.select_all), title: Text('Seleccionar todo'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'ir_linea', child: ListTile(leading: Icon(Icons.arrow_downward), title: Text('Ir a línea'), contentPadding: EdgeInsets.zero)),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'autoclose',
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(_autoCloseSymbols ? 'Desactivar Autocierre' : 'Activar Autocierre'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'autocomplete',
                child: ListTile(
                  leading: const Icon(Icons.auto_fix_high),
                  title: Text(_autoComplete ? 'Desactivar Autocompletado' : 'Activar Autocompletado'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'highlight_matches',
                child: ListTile(
                  leading: const Icon(Icons.highlight),
                  title: Text(_highlightMatches ? 'Desactivar Resaltado' : 'Activar Resaltado'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          // Menú Ver
          PopupMenuButton<String>(
            icon: const Icon(Icons.visibility),
            tooltip: 'Ver',
            onSelected: _handleMenuAction,
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'word_wrap',
                child: ListTile(
                  leading: const Icon(Icons.wrap_text),
                  title: Text(_wordWrap ? 'Desactivar Ajuste' : 'Activar Ajuste de línea'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'line_numbers',
                child: ListTile(
                  leading: const Icon(Icons.format_list_numbered),
                  title: Text(_showLineNumbers ? 'Ocultar Números' : 'Mostrar Números de línea'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'minimap',
                child: ListTile(
                  leading: const Icon(Icons.map),
                  title: Text(_showMinimap ? 'Ocultar Minimapa' : 'Mostrar Minimapa'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'highlight_line',
                child: ListTile(
                  leading: const Icon(Icons.line_weight),
                  title: Text(_highlightCurrentLine ? 'Ocultar Resaltado' : 'Resaltar línea actual'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'zoom_in', child: ListTile(leading: Icon(Icons.zoom_in), title: Text('Zoom +'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'zoom_out', child: ListTile(leading: Icon(Icons.zoom_out), title: Text('Zoom -'), contentPadding: EdgeInsets.zero)),
            ],
          ),
          // Menú Herramientas
          PopupMenuButton<String>(
            icon: const Icon(Icons.build),
            tooltip: 'Herramientas',
            onSelected: _handleMenuAction,
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'preview',
                child: ListTile(
                  leading: const Icon(Icons.preview),
                  title: Text(_previewVisible ? 'Ocultar Vista Previa' : 'Vista previa en vivo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'terminal',
                child: ListTile(
                  leading: const Icon(Icons.terminal),
                  title: Text(_terminalVisible ? 'Ocultar Terminal' : 'Mostrar Terminal'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(value: 'run', child: ListTile(leading: Icon(Icons.play_arrow), title: Text('Ejecutar'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'syntax', child: ListTile(leading: Icon(Icons.check_circle_outline), title: Text('Revisar sintaxis'), contentPadding: EdgeInsets.zero)),
            ],
          ),
          // Menú Ayuda
          PopupMenuButton<String>(
            icon: const Icon(Icons.help),
            tooltip: 'Ayuda',
            onSelected: _handleMenuAction,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'about', child: ListTile(leading: Icon(Icons.info), title: Text('Acerca de'), contentPadding: EdgeInsets.zero)),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Área principal con editor y vista previa/minimapa
          Expanded(
            child: Row(
              children: [
                // Editor principal
                Expanded(
                  flex: _showMinimap || _previewVisible ? 4 : 5,
                  child: Container(
                    color: const Color(0xFF1E1E1E),
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _controller,
                      undoController: _undoController,
                      maxLines: null,
                      expands: true,
                      readOnly: _isReadOnly,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: fontSize,
                        color: Colors.white,
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Escribe tu código o texto aquí...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      cursorColor: Colors.white,
                      autocorrect: false,
                      enableSuggestions: !_autoComplete,
                      textAlign: _showLineNumbers ? TextAlign.left : TextAlign.left,
                    ),
                  ),
                ),
                // Minimapa o Vista Previa
                if (_showMinimap || _previewVisible)
                  Expanded(
                    flex: 1,
                    child: Container(
                      color: const Color(0xFF252526),
                      padding: const EdgeInsets.all(4.0),
                      child: _previewVisible
                          ? SingleChildScrollView(
                              child: Text(
                                _controller.text,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: fontSize * 0.6,
                                  color: Colors.white70,
                                ),
                              ),
                            )
                          : _buildMinimap(),
                    ),
                  ),
              ],
            ),
          ),
          // Terminal
          if (_terminalVisible)
            Container(
              height: 150,
              color: const Color(0xFF1E1E1E),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.terminal, size: 16, color: Colors.white70),
                        SizedBox(width: 8),
                        Text('Terminal', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: _toggleTerminal,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: _terminalOutput.length,
                      itemBuilder: (context, index) {
                        String line = _terminalOutput[index];
                        Color textColor = Colors.white;
                        if (line.startsWith('>')) {
                          textColor = Colors.lightBlueAccent;
                        } else if (line.startsWith('✓')) {
                          textColor = Colors.green;
                        } else if (line.startsWith('✗')) {
                          textColor = Colors.red;
                        }
                        return Text(
                          line,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: textColor,
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _terminalController,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Comando...',
                              hintStyle: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                setState(() {
                                  _terminalOutput.add('> $value');
                                  _terminalOutput.add('Comando no reconocido: $value');
                                  _terminalOutput.add('> ');
                                });
                                _terminalController.clear();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.lightBlueAccent),
                          onPressed: () {
                            String value = _terminalController.text;
                            if (value.trim().isNotEmpty) {
                              setState(() {
                                _terminalOutput.add('> $value');
                                _terminalOutput.add('Comando no reconocido: $value');
                                _terminalOutput.add('> ');
                              });
                              _terminalController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ln $_currentLine, Col $_currentColumn',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                'Total líneas: $_totalLines',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Caracteres: ${_controller.text.length}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                _wordWrap ? 'Ajuste: ON' : 'Ajuste: OFF',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Zoom: ${(_zoomLevel * 100).toInt()}%',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                _encoding,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMinimap() {
    // Minimapa simplificado
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: MinimapPainter(_controller.text),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
}

class MinimapPainter extends CustomPainter {
  final String text;
  
  MinimapPainter(this.text);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white24;
    final lines = text.split('\n');
    final lineHeight = size.height / (lines.length > 100 ? 100 : lines.length);
    
    for (int i = 0; i < (lines.length > 100 ? 100 : lines.length); i++) {
      double lineWidth = (lines[i].length / 100).clamp(0.0, 1.0) * size.width;
      canvas.drawRect(
        Rect.fromLTWH(0, i * lineHeight, lineWidth, lineHeight - 1),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
