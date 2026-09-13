import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        scaffoldBackgroundColor: const Color(0xFF1E1E1E), // Color típico de editores oscuros
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D2D2D),
          foregroundColor: Colors.white,
          elevation: 1,
        ),
        bottomAppBarTheme: const BottomAppBarTheme(
          color: Color(0xFF007ACC), // Azul típico de barra de estado VS Code
          foregroundColor: Colors.white,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF252526),
          textColor: Colors.white,
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
  
  // Estado simulado para la barra de estado
  bool _wordWrap = false;
  String _encoding = 'UTF-8';
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateCursorPosition);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateCursorPosition);
    _controller.dispose();
    super.dispose();
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
    });
  }

  void _showMenu(String category) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Menú $category seleccionado (Funcionalidad pendiente)'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DarkNote - Sin título'),
        actions: [
          // Menú Archivo
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Archivo',
            onSelected: (value) => _showMenu('Archivo'),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'nuevo', child: Text('Nuevo')),
              const PopupMenuItem(value: 'abrir', child: Text('Abrir')),
              const PopupMenuItem(value: 'guardar', child: Text('Guardar')),
              const PopupMenuItem(value: 'guardar_como', child: Text('Guardar como')),
              const PopupMenuItem(value: 'cerrar', child: Text('Cerrar pestaña')),
              const PopupMenuItem(value: 'exportar', child: Text('Exportar PDF')),
              const PopupMenuItem(value: 'solo_lectura', child: Text('Solo lectura')),
            ],
          ),
          // Menú Edición
          PopupMenuButton<String>(
            icon: const Icon(Icons.edit),
            tooltip: 'Edición',
            onSelected: (value) => _showMenu('Edición'),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'deshacer', child: Text('Deshacer')),
              const PopupMenuItem(value: 'rehacer', child: Text('Rehacer')),
              const PopupMenuItem(value: 'buscar', child: Text('Buscar')),
              const PopupMenuItem(value: 'reemplazar', child: Text('Reemplazar')),
              const PopupMenuItem(value: 'seleccionar_todo', child: Text('Seleccionar todo')),
              const PopupMenuItem(value: 'ir_linea', child: Text('Ir a línea')),
            ],
          ),
          // Menú Ver
          PopupMenuButton<String>(
            icon: const Icon(Icons.visibility),
            tooltip: 'Ver',
            onSelected: (value) => _showMenu('Ver'),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'ajuste_linea', child: Text('Ajuste de línea')),
              const PopupMenuItem(value: 'numeros_linea', child: Text('Números de línea')),
              const PopupMenuItem(value: 'minimapa', child: Text('Minimapa')),
              const PopupMenuItem(value: 'resaltar_linea', child: Text('Resaltar línea actual')),
              const PopupMenuItem(value: 'zoom_in', child: Text('Zoom +')),
              const PopupMenuItem(value: 'zoom_out', child: Text('Zoom -')),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Área de edición principal
          Expanded(
            child: Container(
              color: const Color(0xFF1E1E1E),
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _controller,
                maxLines: null, // Permite múltiples líneas infinitas
                expands: true, // Ocupa todo el espacio disponible
                style: const TextStyle(
                  fontFamily: 'monospace', // Fuente monoespaciada para código
                  fontSize: 14.0,
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
                autocorrect: false, // Desactivar autocorrect para código
                enableSuggestions: false,
              ),
            ),
          ),
        ],
      ),
      // Barra de estado inferior fija
      bottomNavigationBar: BottomAppBar(
        elevation: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 8), // Espaciador izquierdo
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
            const SizedBox(width: 8), // Espaciador derecho
          ],
        ),
      ),
    );
  }
}
