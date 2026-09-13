import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        // Corregido: Eliminado foregroundColor incompatible
        bottomAppBarTheme: const BottomAppBarTheme(
          color: Color(0xFF007ACC),
        ),
        // Corregido: Eliminado textColor incompatible, usado style en su lugar
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
  
  final List<String> _history = [];
  int _historyIndex = -1;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _loadPreferences();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
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

  void _onTextChanged() {
    if (!_isTyping) {
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
    
    // Lógica simple de historial
    if (_history.isEmpty || _controller.text != _history.last) {
      _history.add(_controller.text);
      if (_history.length > 50) _history.removeAt(0);
      _historyIndex = _history.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = 14.0 * _zoomLevel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DarkNote'),
        actions: [
          _buildMenu('Archivo', [
            _menuItem('Nuevo', _newFile),
            _menuItem('Abrir', _openFile),
            _menuItem('Guardar', _saveFile),
            _menuItem('Guardar como', _saveFileAs),
            const PopupMenuDivider(),
            _menuItem('Exportar PDF (Pronto)', () => _showMsg('En desarrollo')),
          ]),
          _buildMenu('Edición', [
            _menuItem('Deshacer', _undo),
            _menuItem('Rehacer', _redo),
            const PopupMenuDivider(),
            _menuItem('Buscar', _showSearchDialog),
            _menuItem('Ir a línea', _goToLine),
            _menuItem('Seleccionar todo', _selectAll),
          ]),
          _buildMenu('Ver', [
            _menuItem(_wordWrap ? 'Desactivar Ajuste' : 'Activar Ajuste', _toggleWordWrap),
            _menuItem(_showLineNumbers ? 'Ocultar Números' : 'Mostrar Números', _toggleLineNumbers),
            const PopupMenuDivider(),
            _menuItem('Zoom +', () => _adjustZoom(0.1)),
            _menuItem('Zoom -', () => _adjustZoom(-0.1)),
          ]),
          _buildMenu('Herramientas', [
            _menuItem(_terminalVisible ? 'Ocultar Terminal' : 'Mostrar Terminal', _toggleTerminal),
            _menuItem('Ejecutar Código', _runCode),
            _menuItem('Revisar Sintaxis', _checkSyntax),
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
                    setState(() => _isTyping = true);
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if(mounted) setState(() => _isTyping = false);
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

  // Helper para crear items de menú compatibles
  PopupMenuItem<dynamic> _menuItem(String label, VoidCallback action) {
    return PopupMenuItem<dynamic>(
      child: Text(label),
      onTap: action,
    );
  }

  PopupMenuButton<dynamic> _buildMenu(String title, List<PopupMenuEntry<dynamic>> items) {
    return PopupMenuButton<dynamic>(
      tooltip: title,
      itemBuilder: (context) => items,
    );
  }

  void _newFile() {
    _controller.clear();
    setState(() {
      _history.clear();
      _historyIndex = -1;
    });
    _showMsg("Nuevo archivo creado");
  }

  void _openFile() {
    _showMsg("Abrir archivo: Función pendiente de integración nativa completa");
  }

  void _saveFile() {
    _showMsg("Guardando... (Simulado)");
  }

  void _saveFileAs() {
    _showMsg("Guardar como...");
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
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Buscar"), content: const Text("Función Buscar")));
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
    _showMsg("Sintaxis correcta (Simulado).");
  }

  void _showMsg(String msg) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }
}
