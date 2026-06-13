import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/devolucion_provider.dart';
import '../../providers/pedido_provider.dart';

class DevolucionSolicitudScreen extends StatefulWidget {
  final OrderModel pedido;

  const DevolucionSolicitudScreen({super.key, required this.pedido});

  @override
  State<DevolucionSolicitudScreen> createState() => _DevolucionSolicitudScreenState();
}

class _DevolucionSolicitudScreenState extends State<DevolucionSolicitudScreen> {
  final _motivoController = TextEditingController();
  final _imagePicker = ImagePicker();

  /// {idProducto: cantidadSeleccionada}
  final Map<String, int> _seleccionados = {};

  bool _esDefectuoso = false;
  File? _evidenciaFile;
  Uint8List? _evidenciaBytes;
  String _evidenciaFileName = '';

  final formatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  // ── Selección de imagen ──────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image != null) {
      final fileName = image.name.toLowerCase();
      final ext = fileName.contains('.') ? fileName.split('.').last : '';
      const allowed = ['jpg', 'jpeg', 'png', 'webp'];
      if (!allowed.contains(ext)) {
        _showError('Solo se permiten imágenes (JPG, PNG, WEBP). Archivo: $fileName');
        return;
      }
      final bytes = await image.readAsBytes();
      setState(() {
        _evidenciaBytes = bytes;
        _evidenciaFile = File(image.path);
        _evidenciaFileName = fileName;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _evidenciaFile = null;
      _evidenciaBytes = null;
      _evidenciaFileName = '';
    });
  }

  // ── Toggle selección de producto ─────────────────────────

  void _toggleProducto(OrderItemModel item) {
    setState(() {
      if (_seleccionados.containsKey(item.idProducto)) {
        _seleccionados.remove(item.idProducto);
      } else {
        _seleccionados[item.idProducto] = 1;
      }
    });
  }

  void _updateCantidad(String idProducto, int cantidad, int max) {
    setState(() {
      if (cantidad <= 0) {
        _seleccionados.remove(idProducto);
      } else {
        _seleccionados[idProducto] = cantidad.clamp(1, max);
      }
    });
  }

  // ── Enviar solicitud ─────────────────────────────────────

  Future<void> _submit() async {
    // Validaciones
    if (_seleccionados.isEmpty) {
      _showError('Selecciona al menos un producto');
      return;
    }
    if (_motivoController.text.trim().length < 5) {
      _showError('El motivo debe tener al menos 5 caracteres');
      return;
    }
    if (_evidenciaFile == null) {
      _showError('Adjunta una evidencia fotográfica');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final devolucionProv = Provider.of<DevolucionProvider>(context, listen: false);
    final pedidoProv = Provider.of<PedidoProvider>(context, listen: false);

    if (auth.token == null) return;

    // Subir evidencia
    String? evidenciaUrl;
    if (_evidenciaBytes != null && _evidenciaBytes!.isNotEmpty) {
      evidenciaUrl = await devolucionProv.subirEvidencia(
        bytes: _evidenciaBytes!,
        fileName: _evidenciaFileName.isNotEmpty ? _evidenciaFileName : 'evidencia.jpg',
        userId: auth.userProfile?['id_usuario']?.toString() ?? 'unknown',
      );
      if (evidenciaUrl == null && mounted) {
        _showError(devolucionProv.errorMessage ?? 'Error al subir evidencia');
        return;
      }
    }

    // Construir lista de productos
    final productos = _seleccionados.entries.map((entry) {
      final item = widget.pedido.items.firstWhere((i) => i.idProducto == entry.key);
      return {
        'id_producto': int.parse(entry.key),
        'cantidad': entry.value,
        'precio_unitario': item.precioUnitario,
      };
    }).toList();

    // Crear devolución
    final success = await devolucionProv.crearDevolucion(
      token: auth.token!,
      idPedido: widget.pedido.id,
      idUsuarioCliente: auth.userProfile?['id_usuario']?.toString() ?? '',
      motivo: _motivoController.text.trim(),
      esDefectuoso: _esDefectuoso,
      productos: productos,
      evidenciaUrl: evidenciaUrl,
    );

    if (!mounted) return;

    if (success) {
      // Recargar pedidos para obtener la devolución actualizada
      await pedidoProv.cargarPedidosCliente(auth.token!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud de devolución enviada'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      _showError(devolucionProv.errorMessage ?? 'Error al enviar solicitud');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  // ── UI ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<DevolucionProvider>(context).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar Devolución'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF0F2), Colors.white]),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header del pedido
                    _buildPedidoHeader(),
                    const SizedBox(height: 24),

                    // Selección de productos
                    Text('Selecciona los productos a devolver', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    const SizedBox(height: 12),
                    ...widget.pedido.items.map(_buildProductOption),
                    const SizedBox(height: 24),

                    // Motivo
                    Text('Motivo de la devolución *', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _motivoController,
                      maxLines: 3,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Describe por qué deseas devolver los productos...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.deepRose, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Defectuoso
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _esDefectuoso,
                            onChanged: (v) => setState(() => _esDefectuoso = v ?? false),
                            activeColor: AppTheme.deepRose,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Producto defectuoso', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(
                                  'Si el producto está dañado o defectuoso, marcar esta opción',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Evidencia fotográfica
                    Text('Evidencia fotográfica *', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    const SizedBox(height: 8),
                    if (_evidenciaFile != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: kIsWeb && _evidenciaBytes != null
                                ? Image.memory(_evidenciaBytes!, height: 160, width: double.infinity, fit: BoxFit.cover)
                                : Image.file(_evidenciaFile!, height: 160, width: double.infinity, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _removeImage,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          _buildImagePickerButton(Icons.camera_alt_outlined, 'Cámara', ImageSource.camera),
                          const SizedBox(width: 12),
                          _buildImagePickerButton(Icons.photo_library_outlined, 'Galería', ImageSource.gallery),
                        ],
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            // Botón fijo abajo
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              color: Colors.white,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.deepRose)))
                  : Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), gradient: const LinearGradient(colors: [AppTheme.deepRose, AppTheme.accentColor])),
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('ENVIAR SOLICITUD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidoHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.deepRose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.receipt_long_outlined, color: AppTheme.deepRose, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pedido #${widget.pedido.id}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  '${widget.pedido.fecha.substring(0, 10)}  •  ${formatter.format(widget.pedido.total)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductOption(OrderItemModel item) {
    final seleccionado = _seleccionados.containsKey(item.idProducto);
    final cantidad = _seleccionados[item.idProducto] ?? 0;

    return GestureDetector(
      onTap: () => _toggleProducto(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionado ? AppTheme.deepRose : Colors.grey.shade200,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: seleccionado,
                  onChanged: (_) => _toggleProducto(item),
                  activeColor: AppTheme.deepRose,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.nombreProducto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${item.cantidad}x ${formatter.format(item.precioUnitario)}  =  ${formatter.format(item.subtotal)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (seleccionado) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Cantidad a devolver: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  _qtyButton(
                    icon: Icons.remove,
                    onTap: cantidad > 1 ? () => _updateCantidad(item.idProducto, cantidad - 1, item.cantidad) : null,
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text('$cantidad', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  _qtyButton(
                    icon: Icons.add,
                    onTap: cantidad < item.cantidad ? () => _updateCantidad(item.idProducto, cantidad + 1, item.cantidad) : null,
                  ),
                  Text(' / ${item.cantidad}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _qtyButton({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.deepRose.withValues(alpha: 0.1) : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: enabled ? AppTheme.deepRose : Colors.grey.shade400),
      ),
    );
  }

  Widget _buildImagePickerButton(IconData icon, String label, ImageSource source) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _pickImage(source),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: AppTheme.deepRose),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}
