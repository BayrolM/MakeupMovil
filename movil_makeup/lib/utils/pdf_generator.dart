import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../providers/pedido_provider.dart';

class PdfGenerator {
  static final _currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  static final _dateFormatter = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');

  static PdfColor _statusColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return PdfColors.orange;
      case 'preparado':
        return PdfColors.blue;
      case 'procesando':
        return PdfColors.teal;
      case 'enviado':
        return PdfColors.purple;
      case 'entregado':
        return PdfColors.green;
      case 'cancelado':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }

  static PdfColor _hexColor(String hex) {
    return PdfColor.fromHex(hex);
  }

  static Future<void> generarPdfPedido(OrderModel order, BuildContext context) async {
    final pdf = pw.Document();

    final deepRose = _hexColor('C94A70');
    final gold = _hexColor('D4AF37');
    final darkGrey = _hexColor('333333');
    final lightGrey = _hexColor('F5F5F5');
    final statusColor = _statusColor(order.estado);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(order, deepRose, gold, darkGrey, statusColor),
        footer: (context) => _buildFooter(deepRose),
        build: (context) => [
          _buildCustomerSection(order, darkGrey, lightGrey, deepRose),
          pw.SizedBox(height: 16),
          _buildShippingSection(order, darkGrey, lightGrey, deepRose),
          pw.SizedBox(height: 16),
          _buildItemsTable(order, deepRose, gold, darkGrey, lightGrey),
          pw.SizedBox(height: 16),
          _buildSummarySection(order, deepRose, gold, darkGrey),
          if (order.estado.toLowerCase() == 'enviado' || order.estado.toLowerCase() == 'entregado') ...[
            pw.SizedBox(height: 16),
            _buildTrackingSection(order, deepRose, darkGrey, lightGrey),
          ],
        ],
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'Pedido_${order.id}_GlamourML.pdf';

    if (context.mounted) {
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: fileName,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [xfile],
          subject: '$fileName - GlamourML',
          text: 'Pedido #${order.id} de GlamourML',
        ),
      );
    }
  }

  static pw.Widget _buildHeader(OrderModel order, PdfColor deepRose, PdfColor gold, PdfColor darkGrey, PdfColor statusColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: deepRose, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'GLAMOURML',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: deepRose,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Maquillaje y Belleza Premium',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  order.estado.toUpperCase(),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Pedido #${order.id}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: darkGrey,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Fecha: ${_formatDate(order.fecha)}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCustomerSection(OrderModel order, PdfColor darkGrey, PdfColor lightGrey, PdfColor deepRose) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: lightGrey,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 4, height: 40, color: deepRose),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'INFORMACION DEL CLIENTE',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: deepRose, letterSpacing: 1),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  order.clienteNombre ?? 'Cliente no especificado',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkGrey),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  order.clienteEmail ?? '',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildShippingSection(OrderModel order, PdfColor darkGrey, PdfColor lightGrey, PdfColor deepRose) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: lightGrey,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 4, height: 40, color: _hexColor('D4AF37')),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DIRECCION DE ENVIO',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: deepRose, letterSpacing: 1),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '${order.direccion}, ${order.ciudad}',
                  style: pw.TextStyle(fontSize: 12, color: darkGrey),
                ),
                if (order.departamento != null && order.departamento!.isNotEmpty)
                  pw.Text(
                    order.departamento!,
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(OrderModel order, PdfColor deepRose, PdfColor gold, PdfColor darkGrey, PdfColor lightGrey) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PRODUCTOS',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: deepRose, letterSpacing: 1),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(0.6),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
          },
          border: pw.TableBorder.all(color: PdfColors.grey.shade(200), width: 0.5),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: deepRose),
              children: [
                _tableHeaderCell('#'),
                _tableHeaderCell('PRODUCTO'),
                _tableHeaderCell('CANT'),
                _tableHeaderCell('PRECIO'),
                _tableHeaderCell('SUBTOTAL'),
              ],
            ),
            ...order.items.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              final isEven = index % 2 == 0;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: isEven ? lightGrey : PdfColors.white),
                children: [
                  _tableDataCell('$index', align: pw.TextAlign.center),
                  _tableDataCell(item.nombreProducto),
                  _tableDataCell('${item.cantidad}', align: pw.TextAlign.center),
                  _tableDataCell(_currencyFormatter.format(item.precioUnitario), align: pw.TextAlign.right),
                  _tableDataCell(_currencyFormatter.format(item.subtotal), align: pw.TextAlign.right, bold: true),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _tableDataCell(String text, {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _hexColor('333333'),
        ),
      ),
    );
  }

  static pw.Widget _buildSummarySection(OrderModel order, PdfColor deepRose, PdfColor gold, PdfColor darkGrey) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'METODO DE PAGO',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: deepRose, letterSpacing: 1),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _metodoPagoLabel(order.metodoPago),
                style: pw.TextStyle(fontSize: 11, color: darkGrey),
              ),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: deepRose,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'TOTAL',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                _currencyFormatter.format(order.total),
                style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTrackingSection(OrderModel order, PdfColor deepRose, PdfColor darkGrey, PdfColor lightGrey) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: lightGrey,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'INFORMACION DE ENVIO',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: deepRose, letterSpacing: 1),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              if (order.transportadora != null && order.transportadora!.isNotEmpty) ...[
                pw.Expanded(child: _trackingField('Transportadora', order.transportadora!)),
                pw.SizedBox(width: 16),
              ],
              if (order.numeroGuia != null && order.numeroGuia!.isNotEmpty)
                pw.Expanded(child: _trackingField('No. Guia', order.numeroGuia!)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              if (order.fechaEnvio != null && order.fechaEnvio!.isNotEmpty) ...[
                pw.Expanded(child: _trackingField('Fecha de envio', order.fechaEnvio!)),
                pw.SizedBox(width: 16),
              ],
              if (order.fechaEstimada != null && order.fechaEstimada!.isNotEmpty)
                pw.Expanded(child: _trackingField('Llegada estimada', order.fechaEstimada!)),
            ],
          ),
          if (order.valorPedido != null && order.valorPedido! > 0) ...[
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                pw.Expanded(child: _trackingField('Valor Pedido', '\$${order.valorPedido!.toStringAsFixed(0)}')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _trackingField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _hexColor('333333')),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(PdfColor deepRose) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey.shade(300), width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('GlamourML - Maquillaje y Belleza Premium', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          pw.Text('Generado: ${_dateTimeFormatter.format(DateTime.now())}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ],
      ),
    );
  }

  static String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return _dateFormatter.format(date);
    } catch (_) {
      return dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
    }
  }

  static String _metodoPagoLabel(String metodo) {
    switch (metodo.toLowerCase()) {
      case 'efectivo':
        return 'Contra Entrega (Efectivo)';
      case 'transferencia':
        return 'Transferencia Bancaria';
      case 'tarjeta':
        return 'Tarjeta de Credito/Debito';
      default:
        return metodo;
    }
  }
}
