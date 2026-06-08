import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';
import '../../providers/carrito_provider.dart';
import '../../providers/pedido_provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';

class ClientePagoScreen extends StatefulWidget {
  const ClientePagoScreen({super.key});

  @override
  State<ClientePagoScreen> createState() => _ClientePagoScreenState();
}

class _ClientePagoScreenState extends State<ClientePagoScreen> {
  XFile? _comprobante;
  bool _subiendo = false;
  bool _procesandoPedido = false;
  String? _errorComprobante;

  final ImagePicker _picker = ImagePicker();

  Future<void> _seleccionarComprobante() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image != null) {
      final fileName = image.name.toLowerCase();
      final ext = fileName.split('.').last;
      final allowedExts = ['jpg', 'jpeg', 'png', 'webp'];
      if (!allowedExts.contains(ext)) {
        setState(() => _errorComprobante = 'Solo se permiten imágenes (jpg, png, webp)');
        return;
      }
      setState(() {
        _comprobante = image;
        _errorComprobante = null;
      });
    }
  }

  Future<void> _tomarFoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _comprobante = image;
        _errorComprobante = null;
      });
    }
  }

  Future<String?> _subirComprobante() async {
    if (_comprobante == null) return null;

    final supabase = Supabase.instance.client;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = _comprobante!.name.toLowerCase().split('.').last;
    final storagePath = 'comprobantes/comprobante_${timestamp}.$ext';

    if (kIsWeb) {
      final response = await http.get(Uri.parse(_comprobante!.path));
      if (response.statusCode != 200) return null;
      final bytes = response.bodyBytes;
      await supabase.storage.from('comprobantes').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
    } else {
      final file = File(_comprobante!.path);
      final contentType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      await supabase.storage.from('comprobantes').upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
    }

    return supabase.storage.from('comprobantes').getPublicUrl(storagePath);
  }

  Future<void> _confirmarPago() async {
    if (_comprobante == null) {
      setState(() => _errorComprobante = 'Debes subir un comprobante de pago');
      return;
    }

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final carritoProv = Provider.of<CarritoProvider>(context, listen: false);
    final pedidoProv = Provider.of<PedidoProvider>(context, listen: false);

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final direccion = args?['direccion'] ?? '';
    final ciudad = args?['ciudad'] ?? '';
    final departamento = args?['departamento'] ?? '';

    setState(() {
      _subiendo = true;
      _errorComprobante = null;
    });

    final comprobanteUrl = await _subirComprobante();

    if (comprobanteUrl == null) {
      if (mounted) {
        setState(() => _subiendo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir el comprobante'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() {
      _subiendo = false;
      _procesandoPedido = true;
    });

    final pedidoId = await pedidoProv.crearPedido(
      token: authProv.token!,
      direccion: direccion,
      ciudad: ciudad,
      departamento: departamento,
      metodoPago: 'transferencia',
      items: carritoProv.apiItems,
    );

    if (pedidoId != null) {
      await pedidoProv.actualizarComprobanteUrl(
        token: authProv.token!,
        idPedido: pedidoId,
        comprobanteUrl: comprobanteUrl,
      );
    }

    if (mounted) {
      setState(() => _procesandoPedido = false);

      if (pedidoId != null) {
        carritoProv.limpiar();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text("¡Pedido Recibido!", style: TextStyle(color: AppTheme.deepRose, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text("Tu pedido ha sido registrado. Verificaremos tu comprobante de pago y comenzaremos a preparar tu envío."),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.clientHome, (route) => false);
                },
                child: const Text("ACEPTAR"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pedidoProv.errorMessage ?? 'Error al procesar el pedido'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final carritoProv = Provider.of<CarritoProvider>(context);
    final formatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Realizar Pago"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cuentas bancarias
            const Text("Realiza el pago a una de estas cuentas:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),

            // Bancolombia
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFB641B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance, color: Color(0xFFFB641B), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Bancolombia", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("Cuenta de Ahorros", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          const Text(
                            "No. 1234567890",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 2),
                          Text("A nombre de: GlamourML SAS", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20, color: AppTheme.deepRose),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Número de cuenta copiado'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Nequi
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD92B78).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.phone_android, color: Color(0xFFD92B78), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Nequi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("Cuenta Nequi", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          const Text(
                            "300 123 4567",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 2),
                          Text("A nombre de: GlamourML SAS", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20, color: AppTheme.deepRose),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Número de cuenta copiado'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Resumen del pedido
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Resumen", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...carritoProv.items.values.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.cantidad}x ${item.nombre}',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(formatter.format(item.precio * item.cantidad), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total a pagar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          formatter.format(carritoProv.totalAmount),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.deepRose),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Subir comprobante
            const Text("Comprobante de Pago", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              "Sube una imagen del comprobante de transferencia",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            if (_comprobante != null) ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.deepRose, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: kIsWeb
                    ? Image.network(_comprobante!.path, fit: BoxFit.cover)
                    : Image.file(File(_comprobante!.path), fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _subiendo ? null : _seleccionarComprobante,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Cambiar imagen"),
                ),
              ),
            ] else ...[
              GestureDetector(
                onTap: _subiendo ? null : _seleccionarComprobante,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _errorComprobante != null ? Colors.red : Colors.grey.shade300,
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text("Toca para subir imagen", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text("JPG, PNG o WEBP", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _subiendo ? null : _tomarFoto,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text("Tomar foto"),
                ),
              ),
            ],

            if (_errorComprobante != null) ...[
              const SizedBox(height: 4),
              Text(_errorComprobante!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 24),

            // Botón confirmar
            ElevatedButton(
              onPressed: (_subiendo || _procesandoPedido) ? null : _confirmarPago,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _subiendo
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text("Subiendo comprobante...", style: TextStyle(fontSize: 14)),
                      ],
                    )
                  : _procesandoPedido
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Text("Procesando pedido...", style: TextStyle(fontSize: 14)),
                          ],
                        )
                      : const Text("CONFIRMAR PAGO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
