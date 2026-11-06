import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const EsquitazosApp());
}

class EsquitazosApp extends StatelessWidget {
  const EsquitazosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Esquitazos',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF0E7490),
      ),
      home: const PantallaPrincipal(),
    );
  }
}

// -----------------------------------------------------------------------------
// AYUDANTES DE FECHA NATIVOS
// -----------------------------------------------------------------------------
class Fechas {
  static String horaMinuto(DateTime f) {
    String h = f.hour.toString().padLeft(2, '0');
    String m = f.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  static String diaMesAnio(DateTime f) {
    String d = f.day.toString().padLeft(2, '0');
    String m = f.month.toString().padLeft(2, '0');
    return "$d/$m/${f.year}";
  }

  static String diaMes(DateTime f) {
    String d = f.day.toString().padLeft(2, '0');
    String m = f.month.toString().padLeft(2, '0');
    return "$d/$m";
  }

  static String nombreMesAnio(DateTime f) {
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return "${meses[f.month - 1]} ${f.year}";
  }

  static String nombreDiaSemana(int diaIndex) {
    const dias = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    if (diaIndex >= 1 && diaIndex <= 7) return dias[diaIndex - 1];
    return "N/A";
  }

  static String formatoBalanceDia(DateTime f) {
    int diaSemana = f.weekday;
    String nombreDia = nombreDiaSemana(diaSemana);
    return "$nombreDia, ${diaMesAnio(f)}";
  }
}

// -----------------------------------------------------------------------------
// MODELOS DE DATOS
// -----------------------------------------------------------------------------

class SaborInfo {
  String id;
  String nombre;
  String emoji;
  Color color;
  double precioMediano;
  double precioGrande;
  double costoLoteCompleto;
  double costoInsumosMediano;
  double costoInsumosGrande;
  bool llevaQuesos;
  bool llevaLimon;
  bool llevaHuesito;
  List<int> diasVenta;

  SaborInfo({
    required this.id,
    required this.nombre,
    required this.emoji,
    required this.color,
    required this.precioMediano,
    required this.precioGrande,
    required this.costoLoteCompleto,
    required this.costoInsumosMediano,
    required this.costoInsumosGrande,
    this.llevaQuesos = false,
    this.llevaLimon = true,
    this.llevaHuesito = false,
    this.diasVenta = const [1, 2, 3, 4, 5, 6, 7],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'emoji': emoji,
    'color': color.value, // Retenemos .value por compatibilidad universal
    'precioMediano': precioMediano,
    'precioGrande': precioGrande,
    'costoLoteCompleto': costoLoteCompleto,
    'costoInsumosMediano': costoInsumosMediano,
    'costoInsumosGrande': costoInsumosGrande,
    'llevaQuesos': llevaQuesos,
    'llevaLimon': llevaLimon,
    'llevaHuesito': llevaHuesito,
    'diasVenta': diasVenta,
  };

  factory SaborInfo.fromJson(Map<String, dynamic> json) {
    final nombreNormalizado = '${json['nombre'] ?? ''}'
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    final diasGuardados = json['diasVenta'];
    return SaborInfo(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: json['nombre'],
      emoji: json['emoji'],
      color: Color((json['color'] as num).toInt()),
      precioMediano: (json['precioMediano'] as num).toDouble(),
      precioGrande: (json['precioGrande'] as num).toDouble(),
      costoLoteCompleto: (json['costoLoteCompleto'] as num?)?.toDouble() ?? 0.0,
      costoInsumosMediano:
          (json['costoInsumosMediano'] as num?)?.toDouble() ?? 0.0,
      costoInsumosGrande:
          (json['costoInsumosGrande'] as num?)?.toDouble() ?? 0.0,
      llevaQuesos: json['llevaQuesos'] ?? false,
      llevaLimon: json['llevaLimon'] ?? true,
      llevaHuesito: json['llevaHuesito'] ?? false,
      diasVenta: diasGuardados is List
          ? diasGuardados.map((e) => (e as num).toInt()).toList()
          : (nombreNormalizado.contains('tuetano')
                ? const [5, 6, 7]
                : const [1, 2, 3, 4, 5, 6, 7]),
    );
  }
}

class VentaRegistrada {
  final int numeroVentaDia;
  final DateTime fechaHora;
  final List<Map<String, dynamic>> items;
  final double total;
  final String tipoVenta;
  final double envioAbsorbido;
  final String? pedidoId;

  VentaRegistrada({
    required this.numeroVentaDia,
    required this.fechaHora,
    required this.items,
    required this.total,
    this.tipoVenta = 'puesto',
    this.envioAbsorbido = 0.0,
    this.pedidoId,
  });

  Map<String, dynamic> toJson() => {
    'numeroVentaDia': numeroVentaDia,
    'fechaHora': fechaHora.toIso8601String(),
    'items': items,
    'total': total,
    'tipoVenta': tipoVenta,
    'envioAbsorbido': envioAbsorbido,
    'pedidoId': pedidoId,
  };

  factory VentaRegistrada.fromJson(Map<String, dynamic> json) =>
      VentaRegistrada(
        numeroVentaDia: json['numeroVentaDia'],
        fechaHora: DateTime.parse(json['fechaHora']),
        items: List<Map<String, dynamic>>.from(json['items']),
        total: (json['total'] as num).toDouble(),
        tipoVenta: json['tipoVenta'] ?? 'puesto',
        envioAbsorbido: (json['envioAbsorbido'] as num?)?.toDouble() ?? 0.0,
        pedidoId: json['pedidoId'] as String?,
      );
}

class GastoRegistrado {
  String id;
  DateTime fechaHora;
  double monto;
  String concepto;
  String categoria;
  bool esFugaz;

  GastoRegistrado({
    required this.id,
    required this.fechaHora,
    required this.monto,
    required this.concepto,
    required this.categoria,
    required this.esFugaz,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fechaHora': fechaHora.toIso8601String(),
    'monto': monto,
    'concepto': concepto,
    'categoria': categoria,
    'esFugaz': esFugaz,
  };

  factory GastoRegistrado.fromJson(Map<String, dynamic> json) =>
      GastoRegistrado(
        id: json['id'],
        fechaHora: DateTime.parse(json['fechaHora']),
        monto: (json['monto'] as num).toDouble(),
        concepto: json['concepto'] ?? '',
        categoria: json['categoria'] ?? 'General',
        esFugaz: json['esFugaz'] ?? false,
      );
}

class ClienteDomicilio {
  final String telefono, nombre, calle, numero, colonia, referencias;
  const ClienteDomicilio({
    required this.telefono,
    required this.nombre,
    required this.calle,
    required this.numero,
    required this.colonia,
    required this.referencias,
  });
  Map<String, dynamic> toJson() => {
    'telefono': telefono,
    'nombre': nombre,
    'calle': calle,
    'numero': numero,
    'colonia': colonia,
    'referencias': referencias,
  };
  factory ClienteDomicilio.fromJson(Map<String, dynamic> j) => ClienteDomicilio(
    telefono: '${j['telefono'] ?? ''}',
    nombre: '${j['nombre'] ?? ''}',
    calle: '${j['calle'] ?? ''}',
    numero: '${j['numero'] ?? ''}',
    colonia: '${j['colonia'] ?? ''}',
    referencias: '${j['referencias'] ?? ''}',
  );
}

class PedidoDomicilio {
  final String id;
  final DateTime fechaHora;
  final ClienteDomicilio cliente;
  final List<Map<String, dynamic>> items;
  final double subtotal, envio;
  final String estado;
  final List<String> faltantes;
  final String nota;
  final double envioAbsorbido;
  final bool confirmacionAbierta;
  final bool marcadoListo;
  final bool avisoRepartidorAbierto;
  final bool avisoEnCaminoAbierto;

  const PedidoDomicilio({
    required this.id,
    required this.fechaHora,
    required this.cliente,
    required this.items,
    required this.subtotal,
    required this.envio,
    required this.estado,
    required this.faltantes,
    this.nota = '',
    this.envioAbsorbido = 0.0,
    this.confirmacionAbierta = false,
    this.marcadoListo = false,
    this.avisoRepartidorAbierto = false,
    this.avisoEnCaminoAbierto = false,
  });

  double get total => subtotal + envio;

  PedidoDomicilio copyWith({
    ClienteDomicilio? cliente,
    List<Map<String, dynamic>>? items,
    double? subtotal,
    double? envio,
    String? estado,
    List<String>? faltantes,
    String? nota,
    double? envioAbsorbido,
    bool? confirmacionAbierta,
    bool? marcadoListo,
    bool? avisoRepartidorAbierto,
    bool? avisoEnCaminoAbierto,
  }) => PedidoDomicilio(
    id: id,
    fechaHora: fechaHora,
    cliente: cliente ?? this.cliente,
    items: items ?? this.items,
    subtotal: subtotal ?? this.subtotal,
    envio: envio ?? this.envio,
    estado: estado ?? this.estado,
    faltantes: faltantes ?? this.faltantes,
    nota: nota ?? this.nota,
    envioAbsorbido: envioAbsorbido ?? this.envioAbsorbido,
    confirmacionAbierta: confirmacionAbierta ?? this.confirmacionAbierta,
    marcadoListo: marcadoListo ?? this.marcadoListo,
    avisoRepartidorAbierto:
        avisoRepartidorAbierto ?? this.avisoRepartidorAbierto,
    avisoEnCaminoAbierto: avisoEnCaminoAbierto ?? this.avisoEnCaminoAbierto,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fechaHora': fechaHora.toIso8601String(),
    'cliente': cliente.toJson(),
    'items': items,
    'subtotal': subtotal,
    'envio': envio,
    'estado': estado,
    'faltantes': faltantes,
    'nota': nota,
    'envioAbsorbido': envioAbsorbido,
    'confirmacionAbierta': confirmacionAbierta,
    'marcadoListo': marcadoListo,
    'avisoRepartidorAbierto': avisoRepartidorAbierto,
    'avisoEnCaminoAbierto': avisoEnCaminoAbierto,
  };

  factory PedidoDomicilio.fromJson(Map<String, dynamic> j) => PedidoDomicilio(
    id: '${j['id']}',
    fechaHora: DateTime.parse(j['fechaHora']),
    cliente: ClienteDomicilio.fromJson(Map<String, dynamic>.from(j['cliente'])),
    items: List<Map<String, dynamic>>.from(
      (j['items'] as List).map((e) => Map<String, dynamic>.from(e)),
    ),
    subtotal: (j['subtotal'] as num).toDouble(),
    envio: (j['envio'] as num).toDouble(),
    estado: '${j['estado'] ?? 'Pendiente'}',
    faltantes: List<String>.from(j['faltantes'] ?? const []),
    nota: j['nota'] ?? '',
    envioAbsorbido: (j['envioAbsorbido'] as num?)?.toDouble() ?? 0.0,
    confirmacionAbierta: j['confirmacionAbierta'] as bool? ?? false,
    marcadoListo: j['marcadoListo'] as bool? ?? false,
    avisoRepartidorAbierto: j['avisoRepartidorAbierto'] as bool? ?? false,
    avisoEnCaminoAbierto: j['avisoEnCaminoAbierto'] as bool? ?? false,
  );
}

const Map<String, String> plantillasDomicilioPredeterminadas = {
  'confirmacion': 'Hola {{nombre}}, te confirmo tu pedido de Esquitazos. Ya lo estamos preparando. Total: \${{total}}.',
  'faltantes': 'Hola {{nombre}}, ya recibí tu pedido. Por el momento me faltan: {{faltantes}}. ¿Quieres cancelar el pedido o cambiarlos por otros sabores?',
  'repartidor': 'PEDIDO ESQUITAZOS\nCliente: {{nombre}}\nTeléfono: {{telefono}}\nDirección: {{direccion}}\nReferencias: {{referencias}}\nNota: {{nota}}\n\nPedido:\n{{pedido}}\n\nTotal a cobrar: \${{total}}\nMapa sugerido: {{maps}}',
  'enCamino': 'Hola {{nombre}}, tu pedido ya va en camino. ¡Gracias por pedir en Esquitazos!',
};

// -----------------------------------------------------------------------------
// PANTALLA PRINCIPAL
// -----------------------------------------------------------------------------

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indicePestana = 0;
  bool _cargandoDatos = true;
  bool _mostrarTotalAcumulado = true;
  bool mostrarBilletera = false;

  double nivelTextoMostrador = 3.0;
  double nivelTextoTotal = 3.0;
  double nivelTextoHistorial = 3.0;

  double saldoEfectivoEnMano = 0.0;
  double costoEnvioDefault = 15.0;
  String telefonoRepartidor = '';
  Map<String, String> plantillasMensajes = {
    ...plantillasDomicilioPredeterminadas,
  };

  List<GastoRegistrado> historialGastos = [];
  List<String> categoriasGastos = [
    'Insumos / Plásticos',
    'Ingredientes / Super',
    'Gas / Carbón',
    'Personal / Mío',
    'Moto / Transporte',
    'General',
  ];

  Map<String, Map<String, Map<String, double>>> lotesPorMes = {};
  List<SaborInfo> menuSabores = [];
  Map<String, List<VentaRegistrada>> ventasPorMes = {};
  List<PedidoDomicilio> pedidosDomicilio = [];
  List<ClienteDomicilio> clientesDomicilio = [];
  late DateTime mesVisualizadoResumen;

  final List<Color> paletaColoresDisponibles = [
    const Color(0xFFCA8A04),
    const Color(0xFFDC2626),
    const Color(0xFFEA580C),
    const Color(0xFF854D0E),
    const Color(0xFF16A34A),
    const Color(0xFF2563EB),
    const Color(0xFF9333EA),
    const Color(0xFFDB2777),
  ];

  @override
  void initState() {
    super.initState();
    mesVisualizadoResumen = DateTime.now();
    _cargarDatosDeDisco();
  }

  Future<void> _cargarDatosDeDisco() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _mostrarTotalAcumulado = prefs.getBool('mostrarTotalAcumulado') ?? true;
      mostrarBilletera = prefs.getBool('mostrarBilletera') ?? false;
      nivelTextoMostrador = prefs.getDouble('nivelTextoMostrador') ?? 3.0;
      nivelTextoTotal = prefs.getDouble('nivelTextoTotal') ?? 3.0;
      nivelTextoHistorial = prefs.getDouble('nivelTextoHistorial') ?? 3.0;
      saldoEfectivoEnMano = prefs.getDouble('saldoEfectivoEnMano') ?? 0.0;
      costoEnvioDefault = prefs.getDouble('costoEnvioDefault') ?? 15.0;
      telefonoRepartidor = prefs.getString('telefonoRepartidor') ?? '';
      final plantillasGuardadas = prefs.getString('plantillasMensajes');
      if (plantillasGuardadas != null) {
        plantillasMensajes = {
          ...plantillasDomicilioPredeterminadas,
          ...Map<String, String>.from(jsonDecode(plantillasGuardadas)),
        };
      }

      String? catString = prefs.getString('categoriasGastos');
      if (catString != null) {
        categoriasGastos = List<String>.from(jsonDecode(catString));
      }

      String? gastosString = prefs.getString('historialGastos');
      if (gastosString != null) {
        List<dynamic> jsonList = jsonDecode(gastosString);
        historialGastos = jsonList
            .map((e) => GastoRegistrado.fromJson(e))
            .toList();
      }

      String? saboresString = prefs.getString('menuSabores');
      if (saboresString != null) {
        List<dynamic> jsonList = jsonDecode(saboresString);
        menuSabores = jsonList.map((e) => SaborInfo.fromJson(e)).toList();
      } else {
        menuSabores = [
          SaborInfo(
            id: '1',
            nombre: 'Mantequilla c/ Epazote',
            emoji: '🧈',
            color: const Color(0xFFCA8A04),
            precioMediano: 50.0,
            precioGrande: 70.0,
            costoLoteCompleto: 350.0,
            costoInsumosMediano: 7.0,
            costoInsumosGrande: 10.0,
            llevaQuesos: true,
            llevaLimon: false,
            llevaHuesito: false,
          ),
          SaborInfo(
            id: '2',
            nombre: 'Caldito de Espinazo',
            emoji: '🍖',
            color: const Color(0xFFDC2626),
            precioMediano: 50.0,
            precioGrande: 70.0,
            costoLoteCompleto: 400.0,
            costoInsumosMediano: 6.0,
            costoInsumosGrande: 9.0,
            llevaQuesos: false,
            llevaLimon: true,
            llevaHuesito: true,
          ),
          SaborInfo(
            id: '3',
            nombre: 'Tuétano',
            emoji: '🦴',
            color: const Color(0xFF854D0E),
            precioMediano: 60.0,
            precioGrande: 80.0,
            costoLoteCompleto: 450.0,
            costoInsumosMediano: 7.5,
            costoInsumosGrande: 11.0,
            llevaQuesos: false,
            llevaLimon: true,
            llevaHuesito: false,
            diasVenta: const [5, 6, 7],
          ),
        ];
        _guardarDatosEnDisco();
      }

      String? ventasString = prefs.getString('ventasPorMes');
      if (ventasString != null) {
        Map<String, dynamic> decoded = jsonDecode(ventasString);
        ventasPorMes = decoded.map((claveMes, listaVentasJson) {
          List<dynamic> lista = listaVentasJson as List<dynamic>;
          return MapEntry(
            claveMes,
            lista.map((v) => VentaRegistrada.fromJson(v)).toList(),
          );
        });
      }

      String? lotesString = prefs.getString('lotesPorMes');
      if (lotesString != null) {
        Map<String, dynamic> decoded = jsonDecode(lotesString);
        lotesPorMes = decoded.map((claveMes, mapaDiasJson) {
          Map<String, dynamic> mapaDias = mapaDiasJson as Map<String, dynamic>;
          return MapEntry(
            claveMes,
            mapaDias.map((claveDia, mapaLotesJson) {
              Map<String, dynamic> mapaLotes =
                  mapaLotesJson as Map<String, dynamic>;
              return MapEntry(
                claveDia,
                mapaLotes.map((k, v) => MapEntry(k, (v as num).toDouble())),
              );
            }),
          );
        });
      }

      final pedidosString = prefs.getString('pedidosDomicilio');
      if (pedidosString != null) {
        pedidosDomicilio = (jsonDecode(pedidosString) as List)
            .map((e) => PedidoDomicilio.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      final clientesString = prefs.getString('clientesDomicilio');
      if (clientesString != null) {
        clientesDomicilio = (jsonDecode(clientesString) as List)
            .map((e) => ClienteDomicilio.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      _cargandoDatos = false;
    });
  }

  Future<void> _guardarDatosEnDisco() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mostrarTotalAcumulado', _mostrarTotalAcumulado);
    await prefs.setBool('mostrarBilletera', mostrarBilletera);
    await prefs.setDouble('nivelTextoMostrador', nivelTextoMostrador);
    await prefs.setDouble('nivelTextoTotal', nivelTextoTotal);
    await prefs.setDouble('nivelTextoHistorial', nivelTextoHistorial);
    await prefs.setDouble('saldoEfectivoEnMano', saldoEfectivoEnMano);
    await prefs.setDouble('costoEnvioDefault', costoEnvioDefault);
    await prefs.setString('telefonoRepartidor', telefonoRepartidor);
    await prefs.setString('plantillasMensajes', jsonEncode(plantillasMensajes));

    await prefs.setString('categoriasGastos', jsonEncode(categoriasGastos));
    await prefs.setString(
      'historialGastos',
      jsonEncode(historialGastos.map((g) => g.toJson()).toList()),
    );
    await prefs.setString(
      'menuSabores',
      jsonEncode(menuSabores.map((s) => s.toJson()).toList()),
    );
    await prefs.setString('ventasPorMes', jsonEncode(ventasPorMes));
    await prefs.setString('lotesPorMes', jsonEncode(lotesPorMes));
    await prefs.setString(
      'pedidosDomicilio',
      jsonEncode(pedidosDomicilio.map((p) => p.toJson()).toList()),
    );
    await prefs.setString(
      'clientesDomicilio',
      jsonEncode(clientesDomicilio.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> _exportarDatos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> datosRespaldo = {
        'version_app': '1.0',
        'fecha_respaldo': DateTime.now().toIso8601String(),
        'mostrarTotalAcumulado': prefs.getBool('mostrarTotalAcumulado') ?? true,
        'mostrarBilletera': prefs.getBool('mostrarBilletera') ?? false,
        'nivelTextoMostrador': prefs.getDouble('nivelTextoMostrador') ?? 3.0,
        'nivelTextoTotal': prefs.getDouble('nivelTextoTotal') ?? 3.0,
        'nivelTextoHistorial': prefs.getDouble('nivelTextoHistorial') ?? 3.0,
        'saldoEfectivoEnMano': prefs.getDouble('saldoEfectivoEnMano') ?? 0.0,
        'costoEnvioDefault': prefs.getDouble('costoEnvioDefault') ?? 15.0,
        'telefonoRepartidor': prefs.getString('telefonoRepartidor') ?? '',
        'plantillasMensajes':
            prefs.getString('plantillasMensajes') ??
            jsonEncode(plantillasDomicilioPredeterminadas),
        'categoriasGastos': prefs.getString('categoriasGastos'),
        'historialGastos': prefs.getString('historialGastos'),
        'menuSabores': prefs.getString('menuSabores'),
        'ventasPorMes': prefs.getString('ventasPorMes'),
        'lotesPorMes': prefs.getString('lotesPorMes'),
        'pedidosDomicilio': prefs.getString('pedidosDomicilio') ?? '[]',
        'clientesDomicilio': prefs.getString('clientesDomicilio') ?? '[]',
      };

      String jsonString = jsonEncode(datosRespaldo);
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/esquitazos_respaldo_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(path);
      await file.writeAsString(jsonString);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'Respaldo de datos de Esquitazos 1.0 🌽',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _importarDatos() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isNotEmpty && files.single.path != null) {
        File file = File(files.single.path!);
        String jsonString = await file.readAsString();
        Map<String, dynamic> datosRespaldo = jsonDecode(jsonString);

        final prefs = await SharedPreferences.getInstance();

        if (datosRespaldo.containsKey('mostrarTotalAcumulado')) {
          await prefs.setBool(
            'mostrarTotalAcumulado',
            datosRespaldo['mostrarTotalAcumulado'],
          );
        }
        if (datosRespaldo['mostrarBilletera'] != null) {
          await prefs.setBool(
            'mostrarBilletera',
            datosRespaldo['mostrarBilletera'],
          );
        }
        if (datosRespaldo['nivelTextoMostrador'] != null) {
          await prefs.setDouble(
            'nivelTextoMostrador',
            (datosRespaldo['nivelTextoMostrador'] as num).toDouble(),
          );
        }
        if (datosRespaldo['nivelTextoTotal'] != null) {
          await prefs.setDouble(
            'nivelTextoTotal',
            (datosRespaldo['nivelTextoTotal'] as num).toDouble(),
          );
        }
        if (datosRespaldo['nivelTextoHistorial'] != null) {
          await prefs.setDouble(
            'nivelTextoHistorial',
            (datosRespaldo['nivelTextoHistorial'] as num).toDouble(),
          );
        }
        if (datosRespaldo['saldoEfectivoEnMano'] != null) {
          await prefs.setDouble(
            'saldoEfectivoEnMano',
            (datosRespaldo['saldoEfectivoEnMano'] as num).toDouble(),
          );
        }
        if (datosRespaldo['costoEnvioDefault'] != null) {
          await prefs.setDouble(
            'costoEnvioDefault',
            (datosRespaldo['costoEnvioDefault'] as num).toDouble(),
          );
        }
        if (datosRespaldo['telefonoRepartidor'] != null) {
          await prefs.setString(
            'telefonoRepartidor',
            datosRespaldo['telefonoRepartidor'],
          );
        }
        if (datosRespaldo['plantillasMensajes'] != null) {
          await prefs.setString(
            'plantillasMensajes',
            datosRespaldo['plantillasMensajes'],
          );
        }
        if (datosRespaldo['categoriasGastos'] != null) {
          await prefs.setString(
            'categoriasGastos',
            datosRespaldo['categoriasGastos'],
          );
        }
        if (datosRespaldo['historialGastos'] != null) {
          await prefs.setString(
            'historialGastos',
            datosRespaldo['historialGastos'],
          );
        }
        if (datosRespaldo['menuSabores'] != null) {
          await prefs.setString('menuSabores', datosRespaldo['menuSabores']);
        }
        if (datosRespaldo['ventasPorMes'] != null) {
          await prefs.setString('ventasPorMes', datosRespaldo['ventasPorMes']);
        }
        if (datosRespaldo['lotesPorMes'] != null) {
          await prefs.setString('lotesPorMes', datosRespaldo['lotesPorMes']);
        }
        if (datosRespaldo['pedidosDomicilio'] != null) {
          await prefs.setString(
            'pedidosDomicilio',
            datosRespaldo['pedidosDomicilio'],
          );
        }
        if (datosRespaldo['clientesDomicilio'] != null) {
          await prefs.setString(
            'clientesDomicilio',
            datosRespaldo['clientesDomicilio'],
          );
        }

        await _cargarDatosDeDisco();

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              '✅ ¡Respaldo Importado!',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Tus ventas, gastos, sabores y configuración se han restaurado con éxito.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'EXCELENTE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al importar el archivo: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _obtenerClaveMes(DateTime fecha) =>
      "${fecha.year}_${fecha.month.toString().padLeft(2, '0')}";
  String _obtenerClaveDia(DateTime fecha) =>
      "${fecha.year}_${fecha.month.toString().padLeft(2, '0')}_${fecha.day.toString().padLeft(2, '0')}";

  void _registrarNuevaVenta(
    List<Map<String, dynamic>> items,
    double total, {
    String tipoVenta = 'puesto',
    double envioAbsorbido = 0.0,
    String? pedidoId,
  }) {
    DateTime ahora = DateTime.now();
    String claveMes = _obtenerClaveMes(ahora);

    if (!ventasPorMes.containsKey(claveMes)) {
      ventasPorMes[claveMes] = [];
    }

    int ventasHoy = ventasPorMes[claveMes]!
        .where(
          (v) =>
              v.fechaHora.year == ahora.year &&
              v.fechaHora.month == ahora.month &&
              v.fechaHora.day == ahora.day,
        )
        .length;

    setState(() {
      ventasPorMes[claveMes]!.insert(
        0,
        VentaRegistrada(
          numeroVentaDia: ventasHoy + 1,
          fechaHora: ahora,
          items: List.from(items),
          total: total,
          tipoVenta: tipoVenta,
          envioAbsorbido: envioAbsorbido,
          pedidoId: pedidoId,
        ),
      );
      saldoEfectivoEnMano += total;
    });
    _guardarDatosEnDisco();
  }

  void _registrarGasto(
    double monto,
    String concepto,
    String categoria,
    bool esFugaz,
  ) {
    setState(() {
      historialGastos.insert(
        0,
        GastoRegistrado(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fechaHora: DateTime.now(),
          monto: monto,
          concepto: concepto.isEmpty
              ? (esFugaz ? 'Gasto Fugaz' : 'Gasto Varios')
              : concepto,
          categoria: categoria,
          esFugaz: esFugaz,
        ),
      );
      saldoEfectivoEnMano -= monto;
    });
    _guardarDatosEnDisco();
  }

  void _editarGasto(GastoRegistrado gastoEditado) {
    setState(() {
      int idx = historialGastos.indexWhere((g) => g.id == gastoEditado.id);
      if (idx >= 0) {
        double dif = gastoEditado.monto - historialGastos[idx].monto;
        saldoEfectivoEnMano -= dif;
        historialGastos[idx] = gastoEditado;
      }
    });
    _guardarDatosEnDisco();
  }

  void _eliminarGasto(GastoRegistrado gasto) {
    setState(() {
      saldoEfectivoEnMano += gasto.monto;
      historialGastos.removeWhere((g) => g.id == gasto.id);
    });
    _guardarDatosEnDisco();
  }

  void _actualizarSaldoManual(double nuevoSaldo) {
    setState(() => saldoEfectivoEnMano = nuevoSaldo);
    _guardarDatosEnDisco();
  }

  void _agregarCategoria(String nuevaCat) {
    if (nuevaCat.trim().isEmpty) return;
    setState(() {
      if (!categoriasGastos.contains(nuevaCat.trim())) {
        categoriasGastos.add(nuevaCat.trim());
      }
    });
    _guardarDatosEnDisco();
  }

  void _cambiarLoteSabor(DateTime fecha, String saborId, double fraccion) {
    String claveMes = _obtenerClaveMes(fecha);
    String claveDia = _obtenerClaveDia(fecha);

    setState(() {
      if (!lotesPorMes.containsKey(claveMes)) {
        lotesPorMes[claveMes] = {};
      }
      if (!lotesPorMes[claveMes]!.containsKey(claveDia)) {
        lotesPorMes[claveMes]![claveDia] = {};
      }
      lotesPorMes[claveMes]![claveDia]![saborId] = fraccion;
    });
    _guardarDatosEnDisco();
  }

  void _toggleOjito() {
    setState(() => _mostrarTotalAcumulado = !_mostrarTotalAcumulado);
    _guardarDatosEnDisco();
  }

  void _eliminarVenta(DateTime fechaVenta, VentaRegistrada venta) {
    String claveMes = _obtenerClaveMes(fechaVenta);
    setState(() {
      if (ventasPorMes.containsKey(claveMes)) {
        ventasPorMes[claveMes]!.removeWhere(
          (v) => v.fechaHora == venta.fechaHora && v.total == venta.total,
        );
        saldoEfectivoEnMano -= venta.total;
      }
    });
    _guardarDatosEnDisco();
  }

  void _guardarSabor(SaborInfo saborEditado) {
    setState(() {
      int idx = menuSabores.indexWhere((s) => s.id == saborEditado.id);
      if (idx >= 0) {
        menuSabores[idx] = saborEditado;
      } else {
        menuSabores.add(saborEditado);
      }
    });
    _guardarDatosEnDisco();
  }

  void _eliminarSabor(String id) {
    setState(() {
      menuSabores.removeWhere((s) => s.id == id);
      lotesPorMes.forEach((mes, dias) {
        dias.forEach((dia, mapa) => mapa.remove(id));
      });
    });
    _guardarDatosEnDisco();
  }

  void _cambiarMesResumen(int delta) {
    setState(() {
      mesVisualizadoResumen = DateTime(
        mesVisualizadoResumen.year,
        mesVisualizadoResumen.month + delta,
      );
    });
  }

  void _guardarPedidoDomicilio(PedidoDomicilio pedido) {
    setState(() {
      final i = pedidosDomicilio.indexWhere((p) => p.id == pedido.id);
      if (i < 0) {
        pedidosDomicilio.insert(0, pedido);
      } else {
        pedidosDomicilio[i] = pedido;
      }

      final tel = pedido.cliente.telefono.replaceAll(RegExp(r'\D'), '');

      // Checar si la dirección o nombre es distinto para guardar múltiples direcciones si es el caso
      bool clienteExisteExacto = clientesDomicilio.any(
        (c) =>
            c.telefono.replaceAll(RegExp(r'\D'), '') == tel &&
            c.calle == pedido.cliente.calle &&
            c.numero == pedido.cliente.numero,
      );

      if (!clienteExisteExacto && tel.isNotEmpty) {
        clientesDomicilio.insert(0, pedido.cliente);
      }
    });
    _guardarDatosEnDisco();
  }

  void _borrarPedidoDomicilio(PedidoDomicilio pedido) {
    setState(() {
      pedidosDomicilio.removeWhere((p) => p.id == pedido.id);
      if (pedido.estado == 'En camino') {
        VentaRegistrada? ventaVinculada;
        for (final ventas in ventasPorMes.values) {
          ventaVinculada = ventas
              .where((v) => v.pedidoId == pedido.id)
              .firstOrNull;
          if (ventaVinculada != null) break;
        }
        if (ventaVinculada == null) {
          final candidatas = ventasPorMes.values
              .expand((ventas) => ventas)
              .where(
                (v) =>
                    v.tipoVenta == 'domicilio' &&
                    v.pedidoId == null &&
                    (v.total - pedido.total).abs() < 0.01 &&
                    jsonEncode(v.items) == jsonEncode(pedido.items),
              )
              .toList();
          if (candidatas.length == 1) ventaVinculada = candidatas.single;
        }
        if (ventaVinculada != null) {
          for (final ventas in ventasPorMes.values) {
            if (ventas.remove(ventaVinculada)) {
              saldoEfectivoEnMano -= ventaVinculada.total;
              break;
            }
          }
        }
      }
    });
    _guardarDatosEnDisco();
  }

  void _marcarPedidoEnCamino(PedidoDomicilio pedido) {
    if (pedido.estado == 'En camino') return;
    final items = pedido.items
        .map((i) => Map<String, dynamic>.from(i))
        .toList();
    setState(() {
      final idx = pedidosDomicilio.indexWhere((p) => p.id == pedido.id);
      if (idx >= 0) {
        pedidosDomicilio[idx] = pedido.copyWith(estado: 'En camino');
      }
    });
    _registrarNuevaVenta(
      items,
      pedido.total,
      tipoVenta: 'domicilio',
      envioAbsorbido: pedido.envioAbsorbido,
      pedidoId: pedido.id,
    );
    _guardarDatosEnDisco();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoDatos) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.cyan)),
      );
    }

    String claveMesActual = _obtenerClaveMes(DateTime.now());
    List<VentaRegistrada> ventasMesActual = ventasPorMes[claveMesActual] ?? [];

    final paginaBalance = HistorialPorDiaVista(
      ventasPorMes: ventasPorMes,
      menuSabores: menuSabores,
      lotesPorMes: lotesPorMes,
      nivelTextoHistorial: nivelTextoHistorial,
      mostrarTotalAcumulado: _mostrarTotalAcumulado,
      onToggleOjito: _toggleOjito,
      onEliminarVenta: _eliminarVenta,
      onCambiarLote: _cambiarLoteSabor,
      onAbrirSimulador: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProduccionVista(menuSabores: menuSabores),
        ),
      ),
    );
    final paginaResumen = ResumenMesVista(
      ventasPorMes: ventasPorMes,
      menuSabores: menuSabores,
      lotesPorMes: lotesPorMes,
      mesVisualizado: mesVisualizadoResumen,
      mostrarTotalAcumulado: _mostrarTotalAcumulado,
      onCambiarMes: _cambiarMesResumen,
      historialGastos: historialGastos,
    );
    final paginaBilletera = BilleteraVista(
      saldoEfectivoEnMano: saldoEfectivoEnMano,
      historialGastos: historialGastos,
      categoriasGastos: categoriasGastos,
      mostrarTotalAcumulado: _mostrarTotalAcumulado,
      onRegistrarGasto: _registrarGasto,
      onEditarGasto: _editarGasto,
      onEliminarGasto: _eliminarGasto,
      onActualizarSaldoManual: _actualizarSaldoManual,
      onAgregarCategoria: _agregarCategoria,
    );
    final paginaAjustes = AjustesVista(
      menuSabores: menuSabores,
      paletaColores: paletaColoresDisponibles,
      nivelTextoMostrador: nivelTextoMostrador,
      nivelTextoTotal: nivelTextoTotal,
      nivelTextoHistorial: nivelTextoHistorial,
      costoEnvioDefault: costoEnvioDefault,
      telefonoRepartidor: telefonoRepartidor,
      plantillasMensajes: plantillasMensajes,
      mostrarBilletera: mostrarBilletera,
      onCambiarMostrarBilletera: (v) {
        setState(() {
          final estabaEnAjustes = _indicePestana == (mostrarBilletera ? 4 : 3);
          mostrarBilletera = v;
          if (estabaEnAjustes) _indicePestana = v ? 4 : 3;
        });
        _guardarDatosEnDisco();
      },
      onGuardarPlantillas: (nuevas) {
        setState(
          () => plantillasMensajes = {
            ...plantillasDomicilioPredeterminadas,
            ...nuevas,
          },
        );
        _guardarDatosEnDisco();
      },
      onCambiarNivelMostrador: (v) {
        setState(() => nivelTextoMostrador = v);
        _guardarDatosEnDisco();
      },
      onCambiarNivelTotal: (v) {
        setState(() => nivelTextoTotal = v);
        _guardarDatosEnDisco();
      },
      onCambiarNivelHistorial: (v) {
        setState(() => nivelTextoHistorial = v);
        _guardarDatosEnDisco();
      },
      onCambiarCostoEnvio: (v) {
        setState(() => costoEnvioDefault = v);
        _guardarDatosEnDisco();
      },
      onCambiarTelefonoRepartidor: (v) {
        setState(() => telefonoRepartidor = v);
        _guardarDatosEnDisco();
      },
      onGuardarSabor: _guardarSabor,
      onEliminarSabor: _eliminarSabor,
      onExportar: _exportarDatos,
      onImportar: _importarDatos,
    );

    final paginas = <Widget>[
      CajaYDomicilioVista(
        puesto: CajaRapidaVista(
          menuSabores: menuSabores,
          historialVentasMes: ventasMesActual,
          nivelTextoMostrador: nivelTextoMostrador,
          nivelTextoTotal: nivelTextoTotal,
          onVentaCompletada: (items, total) =>
              _registrarNuevaVenta(items, total),
          onEliminarVenta: _eliminarVenta,
        ),
        domicilio: PedidosDomicilioVista(
          menuSabores: menuSabores,
          clientes: clientesDomicilio,
          pedidos: pedidosDomicilio,
          telefonoRepartidor: telefonoRepartidor,
          costoEnvioDefault: costoEnvioDefault,
          plantillasMensajes: plantillasMensajes,
          onGuardarPedido: _guardarPedidoDomicilio,
          onMarcarEnCamino: _marcarPedidoEnCamino,
          onBorrarPedido: _borrarPedidoDomicilio,
        ),
      ),
      paginaBalance,
      paginaResumen,
      if (mostrarBilletera) paginaBilletera,
      paginaAjustes,
    ];
    final navItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.point_of_sale),
        label: 'Caja',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.analytics),
        label: 'Balance Día',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.pie_chart),
        label: 'Resumen Mes',
      ),
      if (mostrarBilletera)
        const BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet),
          label: 'Billetera',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Ajustes',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _indicePestana, children: paginas),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indicePestana,
        onTap: (index) => setState(() => _indicePestana = index),
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: navItems,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. CAJA RÁPIDA
// -----------------------------------------------------------------------------
class CajaYDomicilioVista extends StatelessWidget {
  final Widget puesto;
  final Widget domicilio;
  const CajaYDomicilioVista({
    super.key,
    required this.puesto,
    required this.domicilio,
  });

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('🌽 Caja'),
        backgroundColor: const Color(0xFF1E293B),
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.storefront), text: 'Puesto'),
            Tab(icon: Icon(Icons.delivery_dining), text: 'Domicilio'),
          ],
        ),
      ),
      body: TabBarView(children: [puesto, domicilio]),
    ),
  );
}

class CajaRapidaVista extends StatefulWidget {
  final List<SaborInfo> menuSabores;
  final List<VentaRegistrada> historialVentasMes;
  final double nivelTextoMostrador;
  final double nivelTextoTotal;
  final Function(List<Map<String, dynamic>>, double) onVentaCompletada;
  final Function(DateTime, VentaRegistrada) onEliminarVenta;

  const CajaRapidaVista({
    super.key,
    required this.menuSabores,
    required this.historialVentasMes,
    required this.nivelTextoMostrador,
    required this.nivelTextoTotal,
    required this.onVentaCompletada,
    required this.onEliminarVenta,
  });

  @override
  State<CajaRapidaVista> createState() => _CajaRapidaVistaState();
}

class _CajaRapidaVistaState extends State<CajaRapidaVista> {
  List<Map<String, dynamic>> itemsCarrito = [];
  double totalOrdenActual = 0.0;
  Timer? _timerGracia;
  int _segundosRestantes = 5;
  Timer? _timerCuentaAtras;
  bool enFaseCongelada = false;
  Timer? _timerRefrescoTiempo;

  double _deltaAcumulado = 0.0;
  bool _mostrarBadgeFlotante = false;
  Timer? _badgeTimer;

  @override
  void initState() {
    super.initState();
    _timerRefrescoTiempo = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timerGracia?.cancel();
    _timerCuentaAtras?.cancel();
    _timerRefrescoTiempo?.cancel();
    _badgeTimer?.cancel();
    super.dispose();
  }

  String _formatearTiempoHace(DateTime fechaHora) {
    final diferencia = DateTime.now().difference(fechaHora);
    if (diferencia.inSeconds < 45) {
      return 'hace ${diferencia.inSeconds}s';
    } else if (diferencia.inMinutes < 60) {
      return 'hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'hace ${diferencia.inHours}h';
    } else {
      return 'hace ${diferencia.inDays}d';
    }
  }

  void _agregarProducto(
    String idSabor,
    String emoji,
    String sabor,
    String tamano,
    double precio,
  ) {
    HapticFeedback.mediumImpact();

    if (enFaseCongelada) {
      setState(() {
        itemsCarrito.clear();
        totalOrdenActual = 0.0;
        enFaseCongelada = false;
        _deltaAcumulado = 0.0;
        _mostrarBadgeFlotante = false;
      });
    }

    setState(() {
      itemsCarrito.add({
        'saborId': idSabor,
        'emoji': emoji,
        'sabor': sabor,
        'tamano': tamano,
        'precio': precio,
      });
      totalOrdenActual += precio;
      _segundosRestantes = 5;
    });

    _iniciarTemporizadores();
  }

  void _ajustarTotalFluido(double cambio) {
    if (itemsCarrito.isEmpty || enFaseCongelada) return;
    HapticFeedback.lightImpact();

    setState(() {
      totalOrdenActual += cambio;
      if (totalOrdenActual < 0) totalOrdenActual = 0;
      _segundosRestantes = 5;

      _deltaAcumulado += cambio;
      _mostrarBadgeFlotante = true;
    });
    _iniciarTemporizadores();

    _badgeTimer?.cancel();
    _badgeTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _mostrarBadgeFlotante = false;
          _deltaAcumulado = 0.0;
        });
      }
    });
  }

  void _deshacerUltimo() {
    HapticFeedback.heavyImpact();
    if (itemsCarrito.isEmpty || enFaseCongelada) return;
    setState(() {
      var ultimo = itemsCarrito.removeLast();
      totalOrdenActual -= (ultimo['precio'] as double);
      if (totalOrdenActual < 0) totalOrdenActual = 0;
      if (itemsCarrito.isEmpty) {
        _cancelarTemporizadores();
        totalOrdenActual = 0.0;
        _deltaAcumulado = 0.0;
        _mostrarBadgeFlotante = false;
      }
    });
  }

  void _iniciarTemporizadores() {
    _timerGracia?.cancel();
    _timerCuentaAtras?.cancel();

    _timerCuentaAtras = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_segundosRestantes > 1) {
        setState(() => _segundosRestantes--);
      } else {
        timer.cancel();
      }
    });

    _timerGracia = Timer(const Duration(seconds: 5), _congelarYGuardarOrden);
  }

  void _cancelarTemporizadores() {
    _timerGracia?.cancel();
    _timerCuentaAtras?.cancel();
    _segundosRestantes = 5;
  }

  void _registrarInmediato() {
    if (itemsCarrito.isEmpty || enFaseCongelada) return;
    _cancelarTemporizadores();
    _congelarYGuardarOrden();
  }

  void _congelarYGuardarOrden() {
    if (itemsCarrito.isEmpty || !mounted) return;
    HapticFeedback.vibrate();
    widget.onVentaCompletada(itemsCarrito, totalOrdenActual);
    setState(() {
      enFaseCongelada = true;
      _mostrarBadgeFlotante = false;
      _deltaAcumulado = 0.0;
    });
    _timerCuentaAtras?.cancel();

    Timer(const Duration(seconds: 15), () {
      if (mounted && enFaseCongelada) {
        setState(() {
          itemsCarrito.clear();
          totalOrdenActual = 0.0;
          enFaseCongelada = false;
          _segundosRestantes = 5;
        });
      }
    });
  }

  void _confirmarBorradoVentaRapida(VentaRegistrada v) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 26,
            ),
            SizedBox(width: 8),
            Text(
              '¿Eliminar esta venta?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Vas a eliminar la venta #${v.numeroVentaDia} por \$${v.total.toStringAsFixed(0)}. Esta acción descontará el dinero de tu efectivo en mano.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              widget.onEliminarVenta(v.fechaHora, v);
              Navigator.pop(context);
            },
            child: const Text(
              'SÍ, BORRAR VENTA',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime ahora = DateTime.now();
    final ultimas3Hoy = widget.historialVentasMes
        .where(
          (v) =>
              v.fechaHora.year == ahora.year &&
              v.fechaHora.month == ahora.month &&
              v.fechaHora.day == ahora.day,
        )
        .take(3)
        .toList();

    double fontBoton = 10.0 + (widget.nivelTextoMostrador * 2.0);
    double fontPrecio = 12.0 + (widget.nivelTextoMostrador * 2.0);
    double fontTotalNum = 20.0 + (widget.nivelTextoTotal * 2.5);

    return Stack(
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E293B),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🕒 Últimas Ventas de Hoy:',
                    style: TextStyle(
                      color: Colors.cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (ultimas3Hoy.isEmpty)
                    const Text(
                      'Esperando primera venta del día...',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ultimas3Hoy.map((v) {
                          String resumen = v.items
                              .map(
                                (i) =>
                                    '${i['emoji']}${i['tamano'].substring(0, 1)}',
                              )
                              .join(', ');
                          String haceCuanto = _formatearTiempoHace(v.fechaHora);
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.cyan.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '#${v.numeroVentaDia} ➔ $resumen (\$${v.total.toStringAsFixed(0)})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.cyan.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    haceCuanto,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.cyan,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _confirmarBorradoVentaRapida(v),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.redAccent,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columnas = constraints.maxWidth >= 600 ? 3 : 2;
                  final filas = (widget.menuSabores.length / columnas)
                      .ceil()
                      .clamp(1, 999);
                  final altoNatural = (constraints.maxHeight - 8) / filas;
                  final altoCelda = altoNatural.clamp(44.0, 110.0).toDouble();
                  return GridView.builder(
                    physics: altoNatural < 55
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(4),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnas,
                      mainAxisExtent: altoCelda,
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                    ),
                    itemCount: widget.menuSabores.length,
                    itemBuilder: (context, index) {
                      final sabor = widget.menuSabores[index];
                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Column(
                            children: [
                              Text(
                                '${sabor.emoji} ${sabor.nombre}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _BotonPop(
                                        label: 'MED',
                                        precio: sabor.precioMediano,
                                        color: sabor.color,
                                        fontSizeLabel: fontBoton
                                            .clamp(9, 12)
                                            .toDouble(),
                                        fontSizePrecio: fontPrecio
                                            .clamp(10, 14)
                                            .toDouble(),
                                        onTap: () => _agregarProducto(
                                          sabor.id,
                                          sabor.emoji,
                                          sabor.nombre,
                                          'Mediano',
                                          sabor.precioMediano,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: _BotonPop(
                                        label: 'GDE',
                                        precio: sabor.precioGrande,
                                        color: sabor.color,
                                        fontSizeLabel: fontBoton
                                            .clamp(9, 12)
                                            .toDouble(),
                                        fontSizePrecio: fontPrecio
                                            .clamp(10, 14)
                                            .toDouble(),
                                        onTap: () => _agregarProducto(
                                          sabor.id,
                                          sabor.emoji,
                                          sabor.nombre,
                                          'Grande',
                                          sabor.precioGrande,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (itemsCarrito.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: const Color(0xFF0F172A),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_cart,
                      color: Colors.cyan,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          itemsCarrito
                              .map((e) => '${e['emoji']} ${e['tamano']}')
                              .join(' + '),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (!enFaseCongelada) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: const Size(70, 30),
                        ),
                        onPressed: _registrarInmediato,
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text(
                          'REGISTRAR YA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _ajustarTotalFluido(-5.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: const Text(
                            '-5',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _ajustarTotalFluido(5.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.greenAccent),
                          ),
                          child: const Text(
                            '+5',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: _deshacerUltimo,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(45, 30),
                        ),
                        child: const Text(
                          'DESHACER',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: enFaseCongelada
                  ? const Color(0xFF15803D)
                  : (itemsCarrito.isNotEmpty
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF1E293B)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          enFaseCongelada
                              ? '✅ ORDEN COBRADA'
                              : (itemsCarrito.isNotEmpty
                                    ? '⏳ Guardando automáticamente en ${_segundosRestantes}s...'
                                    : 'Esperando cliente...'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '\$${totalOrdenActual.toStringAsFixed(2)} MXN',
                          style: TextStyle(
                            fontSize: fontTotalNum,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (enFaseCongelada) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        minimumSize: const Size(90, 36),
                      ),
                      onPressed: () {
                        setState(() {
                          itemsCarrito.clear();
                          totalOrdenActual = 0.0;
                          enFaseCongelada = false;
                        });
                      },
                      child: const Text(
                        'SIGUIENTE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 110,
          right: 20,
          child: AnimatedOpacity(
            opacity: _mostrarBadgeFlotante ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: AnimatedScale(
              scale: _mostrarBadgeFlotante ? 1.0 : 0.7,
              duration: const Duration(milliseconds: 250),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _deltaAcumulado >= 0
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _deltaAcumulado >= 0
                          ? Icons.add_circle
                          : Icons.remove_circle,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_deltaAcumulado >= 0 ? '+' : ''}\$${_deltaAcumulado.toInt()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 2. BILLETERA
// -----------------------------------------------------------------------------
class BilleteraVista extends StatefulWidget {
  final double saldoEfectivoEnMano;
  final List<GastoRegistrado> historialGastos;
  final List<String> categoriasGastos;
  final bool mostrarTotalAcumulado;
  final Function(double, String, String, bool) onRegistrarGasto;
  final Function(GastoRegistrado) onEditarGasto;
  final Function(GastoRegistrado) onEliminarGasto;
  final Function(double) onActualizarSaldoManual;
  final Function(String) onAgregarCategoria;

  const BilleteraVista({
    super.key,
    required this.saldoEfectivoEnMano,
    required this.historialGastos,
    required this.categoriasGastos,
    required this.mostrarTotalAcumulado,
    required this.onRegistrarGasto,
    required this.onEditarGasto,
    required this.onEliminarGasto,
    required this.onActualizarSaldoManual,
    required this.onAgregarCategoria,
  });

  @override
  State<BilleteraVista> createState() => _BilleteraVistaState();
}

class _BilleteraVistaState extends State<BilleteraVista> {
  final TextEditingController _montoFugazCtrl = TextEditingController();

  @override
  void dispose() {
    _montoFugazCtrl.dispose();
    super.dispose();
  }

  void _abrirModalAjustarSaldo() {
    TextEditingController saldoCtrl = TextEditingController(
      text: widget.saldoEfectivoEnMano.toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          '✏️ Ajustar Dinero Real en Mano',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa el dinero físico exacto que traes en el bolsillo ahorita:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: saldoCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto total (\$ MXN)',
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              double n =
                  double.tryParse(saldoCtrl.text) ?? widget.saldoEfectivoEnMano;
              widget.onActualizarSaldoManual(n);
              Navigator.pop(context);
            },
            child: const Text(
              'GUARDAR SALDO',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirModalGastoDetallado() {
    TextEditingController montoCtrl = TextEditingController();
    TextEditingController conceptoCtrl = TextEditingController();
    String catSel = widget.categoriasGastos.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              '📝 Registrar Gasto Detallado',
              style: TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Monto (\$ MXN)',
                      labelStyle: TextStyle(color: Colors.cyan),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: conceptoCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: '¿En qué se gastó? (Ej. Hielo, Gas)',
                      labelStyle: TextStyle(color: Colors.cyan),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Categoría:',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      InkWell(
                        onTap: () {
                          TextEditingController nuevaCatCtrl =
                              TextEditingController();
                          showDialog(
                            context: context,
                            builder: (c) => AlertDialog(
                              backgroundColor: const Color(0xFF0F172A),
                              title: const Text(
                                'Nueva Categoría',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              content: TextField(
                                controller: nuevaCatCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Nombre',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    widget.onAgregarCategoria(
                                      nuevaCatCtrl.text,
                                    );
                                    Navigator.pop(c);
                                    setStateModal(
                                      () => catSel = nuevaCatCtrl.text,
                                    );
                                  },
                                  child: const Text('Agregar'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text(
                          '+ Crear Nueva',
                          style: TextStyle(
                            color: Colors.cyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  DropdownButton<String>(
                    value: widget.categoriasGastos.contains(catSel)
                        ? catSel
                        : widget.categoriasGastos.first,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white),
                    items: widget.categoriasGastos
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateModal(() => catSel = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'CANCELAR',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  double m = double.tryParse(montoCtrl.text) ?? 0.0;
                  if (m > 0) {
                    widget.onRegistrarGasto(
                      m,
                      conceptoCtrl.text,
                      catSel,
                      false,
                    );
                  }
                  Navigator.pop(context);
                },
                child: const Text(
                  'REGISTRAR SALIDA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _abrirModalEditarGasto(GastoRegistrado gasto) {
    TextEditingController montoCtrl = TextEditingController(
      text: gasto.monto.toStringAsFixed(0),
    );
    TextEditingController conceptoCtrl = TextEditingController(
      text: gasto.concepto,
    );
    String catSel = gasto.categoria;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Text(
              gasto.esFugaz ? '⚡ Nombrar Gasto Fugaz' : 'Editar Gasto',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hora registrada: ${Fechas.horaMinuto(gasto.fechaHora)} hrs',
                    style: const TextStyle(color: Colors.cyan, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Monto (\$ MXN)',
                      labelStyle: TextStyle(color: Colors.cyan),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: conceptoCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nombre / Concepto',
                      labelStyle: TextStyle(color: Colors.cyan),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButton<String>(
                    value: widget.categoriasGastos.contains(catSel)
                        ? catSel
                        : widget.categoriasGastos.first,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white),
                    items: widget.categoriasGastos
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateModal(() => catSel = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () {
                  widget.onEliminarGasto(gasto);
                  Navigator.pop(context);
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'CANCELAR',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  gasto.monto = double.tryParse(montoCtrl.text) ?? gasto.monto;
                  gasto.concepto = conceptoCtrl.text;
                  gasto.categoria = catSel;
                  gasto.esFugaz = false;
                  widget.onEditarGasto(gasto);
                  Navigator.pop(context);
                },
                child: const Text(
                  'GUARDAR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color colorSaldo = Colors.cyan;
    if (!widget.mostrarTotalAcumulado) {
      colorSaldo = Colors.white;
    } else {
      colorSaldo = widget.saldoEfectivoEnMano >= 0
          ? Colors.cyan
          : Colors.redAccent;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '💳 Tu Billetera Real',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '💵 Dinero Físico en Mano',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.cyan,
                          size: 20,
                        ),
                        tooltip: 'Ajustar Saldo Real',
                        onPressed: _abrirModalAjustarSaldo,
                      ),
                    ],
                  ),
                  Text(
                    widget.mostrarTotalAcumulado
                        ? '\$${widget.saldoEfectivoEnMano.toStringAsFixed(2)} MXN'
                        : '\$ • • • • •',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: colorSaldo,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Se suma automáticamente con cada venta cobrada.',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt, color: Colors.amberAccent, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Gasto Fugaz Express',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _montoFugazCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Ej. 70',
                            hintStyle: const TextStyle(color: Colors.white24),
                            prefixText: '\$ ',
                            prefixStyle: const TextStyle(
                              color: Colors.cyan,
                              fontSize: 18,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          double m =
                              double.tryParse(_montoFugazCtrl.text) ?? 0.0;
                          if (m > 0) {
                            widget.onRegistrarGasto(m, '', 'General', true);
                            _montoFugazCtrl.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '⚡ Gasto de \$$m guardado con la hora actual.',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'DESCONTAR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🧾 Historial de Gastos:',
                style: TextStyle(
                  color: Colors.cyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.cyan,
                  side: const BorderSide(color: Colors.cyan),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Gasto Detallado',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: _abrirModalGastoDetallado,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.historialGastos.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No has registrado salidas de dinero.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...widget.historialGastos.map((gasto) {
              String horaStr = Fechas.horaMinuto(gasto.fechaHora);
              String fechaStr = Fechas.diaMes(gasto.fechaHora);

              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: gasto.esFugaz
                        ? Colors.amberAccent.withValues(alpha: 0.2)
                        : Colors.redAccent.withValues(alpha: 0.2),
                    child: Icon(
                      gasto.esFugaz ? Icons.bolt : Icons.receipt,
                      color: gasto.esFugaz
                          ? Colors.amberAccent
                          : Colors.redAccent,
                      size: 18,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        '-\$${gasto.monto.toStringAsFixed(2)} MXN',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$fechaStr $horaStr hrs',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      gasto.esFugaz
                          ? '⚡ Gasto Fugaz (Toca para nombrar)'
                          : '${gasto.concepto} • [${gasto.categoria}]',
                      style: TextStyle(
                        color: gasto.esFugaz
                            ? Colors.amberAccent
                            : Colors.white60,
                        fontSize: 11,
                        fontStyle: gasto.esFugaz
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () => _abrirModalEditarGasto(gasto),
                ),
              );
            }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. BALANCE DIARIO
// -----------------------------------------------------------------------------
class HistorialPorDiaVista extends StatefulWidget {
  final Map<String, List<VentaRegistrada>> ventasPorMes;
  final List<SaborInfo> menuSabores;
  final Map<String, Map<String, Map<String, double>>> lotesPorMes;
  final double nivelTextoHistorial;
  final bool mostrarTotalAcumulado;
  final VoidCallback onToggleOjito;
  final Function(DateTime, VentaRegistrada) onEliminarVenta;
  final Function(DateTime, String, double) onCambiarLote;
  final VoidCallback onAbrirSimulador;

  const HistorialPorDiaVista({
    super.key,
    required this.ventasPorMes,
    required this.menuSabores,
    required this.lotesPorMes,
    required this.nivelTextoHistorial,
    required this.mostrarTotalAcumulado,
    required this.onToggleOjito,
    required this.onEliminarVenta,
    required this.onCambiarLote,
    required this.onAbrirSimulador,
  });

  @override
  State<HistorialPorDiaVista> createState() => _HistorialPorDiaVistaState();
}

class _HistorialPorDiaVistaState extends State<HistorialPorDiaVista> {
  final Set<String> _diasDesbloqueados = {};

  String _obtenerClaveMes(DateTime fecha) =>
      "${fecha.year}_${fecha.month.toString().padLeft(2, '0')}";
  String _obtenerClaveDia(DateTime fecha) =>
      "${fecha.year}_${fecha.month.toString().padLeft(2, '0')}_${fecha.day.toString().padLeft(2, '0')}";

  void _confirmarBorradoVenta(DateTime fechaVenta, VentaRegistrada venta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 26,
            ),
            SizedBox(width: 8),
            Text(
              '¿Estás seguro?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Vas a borrar la venta #${venta.numeroVentaDia} por \$${venta.total.toStringAsFixed(0)}. Esta acción no se puede deshacer.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              widget.onEliminarVenta(fechaVenta, venta);
              Navigator.pop(context);
            },
            child: const Text(
              'SÍ, BORRAR',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime ahora = DateTime.now();
    String claveMesActual = _obtenerClaveMes(ahora);
    List<VentaRegistrada> ventasMes = widget.ventasPorMes[claveMesActual] ?? [];

    Map<String, List<VentaRegistrada>> ventasAgrupadas = {};
    for (var venta in ventasMes) {
      String claveDia = _obtenerClaveDia(venta.fechaHora);
      ventasAgrupadas.putIfAbsent(claveDia, () => []).add(venta);
    }

    for (final claveDia in (widget.lotesPorMes[claveMesActual] ?? {}).keys) {
      ventasAgrupadas.putIfAbsent(claveDia, () => []);
    }

    String hoyClave = _obtenerClaveDia(ahora);
    ventasAgrupadas.putIfAbsent(hoyClave, () => []);

    final diasOrdenados = ventasAgrupadas.keys.toList();
    diasOrdenados.sort((a, b) => b.compareTo(a));

    double fontSizeBase = 12.0 + (widget.nivelTextoHistorial * 2.0);
    String mesActualNombre = Fechas.nombreMesAnio(ahora);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '📊 Balance Diario - $mesActualNombre',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            tooltip: 'Simulador de evento',
            icon: const Icon(Icons.calculate, color: Colors.cyanAccent),
            onPressed: widget.onAbrirSimulador,
          ),
          IconButton(
            icon: Icon(
              widget.mostrarTotalAcumulado
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: Colors.cyan,
            ),
            onPressed: widget.onToggleOjito,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: diasOrdenados.length,
        itemBuilder: (context, index) {
          String claveDiaStr = diasOrdenados[index];
          List<VentaRegistrada> ventasDelDia = ventasAgrupadas[claveDiaStr]!;

          DateTime fechaObj = ventasDelDia.isNotEmpty
              ? ventasDelDia.first.fechaHora
              : DateTime(
                  int.parse(claveDiaStr.split('_')[0]),
                  int.parse(claveDiaStr.split('_')[1]),
                  int.parse(claveDiaStr.split('_')[2]),
                );

          String diaFormateadoStr = Fechas.formatoBalanceDia(fechaObj);

          bool esHoy = Fechas.diaMesAnio(fechaObj) == Fechas.diaMesAnio(ahora);
          bool estaDesbloqueado = _diasDesbloqueados.contains(claveDiaStr);
          bool sePuedeEditar = esHoy || estaDesbloqueado;

          double ventaTotalBruta = ventasDelDia.fold(
            0.0,
            (sum, item) => sum + item.total,
          );
          double envioAbsorbidoTotal = ventasDelDia.fold(
            0.0,
            (sum, item) => sum + item.envioAbsorbido,
          );

          double gastoInsumosVariables = 0.0;
          for (var v in ventasDelDia) {
            for (var item in v.items) {
              String sNombre = item['sabor'] ?? '';
              String sTamano = item['tamano'] ?? '';
              var saborObj = widget.menuSabores.firstWhere(
                (s) => s.nombre == sNombre || sNombre.contains(s.nombre),
                orElse: () => SaborInfo(
                  id: '',
                  nombre: '',
                  emoji: '',
                  color: Colors.white,
                  precioMediano: 0,
                  precioGrande: 0,
                  costoLoteCompleto: 0,
                  costoInsumosMediano: 0,
                  costoInsumosGrande: 0,
                ),
              );
              if (sTamano == 'Mediano') {
                gastoInsumosVariables += saborObj.costoInsumosMediano;
              }
              if (sTamano == 'Grande') {
                gastoInsumosVariables += saborObj.costoInsumosGrande;
              }
            }
          }

          String claveMes = _obtenerClaveMes(fechaObj);
          String claveDia = _obtenerClaveDia(fechaObj);
          Map<String, double> lotesDelDia =
              widget.lotesPorMes[claveMes]?[claveDia] ?? {};

          double gastoCocinadaDia = 0.0;
          lotesDelDia.forEach((saborId, fraccion) {
            var saborObj = widget.menuSabores.firstWhere(
              (s) => s.id == saborId,
              orElse: () => widget.menuSabores.first,
            );
            gastoCocinadaDia += (saborObj.costoLoteCompleto * fraccion);
          });

          double gastoTotalDia =
              gastoCocinadaDia + gastoInsumosVariables + envioAbsorbidoTotal;
          double resultadoNeto = ventaTotalBruta - gastoTotalDia;

          Color colorResultadoNeto;
          if (!widget.mostrarTotalAcumulado) {
            colorResultadoNeto = Colors.white;
          } else {
            colorResultadoNeto = resultadoNeto >= 0
                ? Colors.greenAccent
                : Colors.redAccent;
          }

          Map<String, int> conteoVasosDiaMediano = {};
          Map<String, int> conteoVasosDiaGrande = {};
          int totalVasosMedianosDia = 0;
          int totalVasosGrandesDia = 0;

          for (var venta in ventasDelDia) {
            for (var item in venta.items) {
              String sabor = item['sabor'] ?? 'Desconocido';
              String tamano = item['tamano'] ?? '';
              if (tamano == 'Mediano') {
                conteoVasosDiaMediano[sabor] =
                    (conteoVasosDiaMediano[sabor] ?? 0) + 1;
                totalVasosMedianosDia++;
              } else if (tamano == 'Grande') {
                conteoVasosDiaGrande[sabor] =
                    (conteoVasosDiaGrande[sabor] ?? 0) + 1;
                totalVasosGrandesDia++;
              }
            }
          }

          return Card(
            color: const Color(0xFF1E293B),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ExpansionTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      diaFormateadoStr,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: fontSizeBase,
                      ),
                    ),
                  ),
                  if (!esHoy)
                    IconButton(
                      icon: Icon(
                        estaDesbloqueado ? Icons.lock_open : Icons.edit,
                        color: estaDesbloqueado
                            ? Colors.greenAccent
                            : Colors.amberAccent,
                        size: 20,
                      ),
                      tooltip: estaDesbloqueado
                          ? 'Día desbloqueado para edición'
                          : 'Desbloquear edición con lápiz',
                      onPressed: () {
                        setState(() {
                          if (estaDesbloqueado) {
                            _diasDesbloqueados.remove(claveDiaStr);
                          } else {
                            _diasDesbloqueados.add(claveDiaStr);
                          }
                        });
                      },
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.mostrarTotalAcumulado
                            ? 'Venta Bruta: \$${ventaTotalBruta.toStringAsFixed(0)}'
                            : 'Venta Bruta: \$ • • •',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        widget.mostrarTotalAcumulado
                            ? 'Gasto Día: \$${gastoTotalDia.toStringAsFixed(0)}'
                            : 'Gasto Día: \$ • • •',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.mostrarTotalAcumulado
                        ? 'Ganancia Neta: \$${resultadoNeto.toStringAsFixed(2)} MXN'
                        : 'Ganancia Neta: \$ • • • • •',
                    style: TextStyle(
                      color: colorResultadoNeto,
                      fontWeight: FontWeight.bold,
                      fontSize: fontSizeBase,
                    ),
                  ),
                ],
              ),
              children: [
                Container(
                  color: const Color(0xFF141D2F),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🥤 Total Vasos Vendidos:',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Medianos: $totalVasosMedianosDia  |  Grandes: $totalVasosGrandesDia',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: const Color(0xFF0F172A),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🍿 Desglose por Sabor (Vasos Hoy):',
                        style: TextStyle(
                          color: Colors.cyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (ventasDelDia.isEmpty)
                        const Text(
                          'Aún sin ventas registradas este día.',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        )
                      else
                        ...widget.menuSabores.map((sabor) {
                          int med = conteoVasosDiaMediano[sabor.nombre] ?? 0;
                          int gde = conteoVasosDiaGrande[sabor.nombre] ?? 0;
                          if (med == 0 && gde == 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${sabor.emoji} ${sabor.nombre}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  'Med: $med | Gde: $gde',
                                  style: const TextStyle(
                                    color: Colors.cyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Container(
                  color: const Color(0xFF0F172A),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '🔥 Cocinada / Lotes preparados este día:',
                            style: TextStyle(
                              color: Colors.cyan,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!sePuedeEditar)
                            const Text(
                              '🔒 Bloqueado (Toca el lápiz para editar)',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...widget.menuSabores.map((sabor) {
                        double fraccionActual = lotesDelDia[sabor.id] ?? 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  '${sabor.emoji} ${sabor.nombre}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 6,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [0.0, 0.33, 0.5, 1.0, 2.0, 3.0].map((
                                      fraccion,
                                    ) {
                                      bool sel = fraccionActual == fraccion;
                                      String lbl = fraccion == 0.0
                                          ? '❌ 0'
                                          : (fraccion == 0.33
                                                ? '⅓'
                                                : (fraccion == 0.5
                                                      ? '½'
                                                      : (fraccion == 1.0
                                                            ? '🟢 1'
                                                            : '${fraccion.toInt()}')));
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: InkWell(
                                          onTap: sePuedeEditar
                                              ? () => widget.onCambiarLote(
                                                  fechaObj,
                                                  sabor.id,
                                                  fraccion,
                                                )
                                              : () {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            '⚠ Día pasado bloqueado. Toca el icono de lápiz arriba para desbloquear.',
                                                          ),
                                                          duration: Duration(
                                                            seconds: 2,
                                                          ),
                                                        ),
                                                      );
                                                },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: sel
                                                  ? Colors.cyan
                                                  : const Color(0xFF1E293B),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: sel
                                                    ? Colors.white
                                                    : Colors.white24,
                                              ),
                                            ),
                                            child: Text(
                                              lbl,
                                              style: TextStyle(
                                                color: sel
                                                    ? Colors.black
                                                    : Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                ...ventasDelDia.map((venta) {
                  return Container(
                    color: const Color(0xFF0F172A),
                    child: ListTile(
                      title: Text(
                        'Venta #${venta.numeroVentaDia} - \$${venta.total.toStringAsFixed(2)} MXN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Hora: ${Fechas.horaMinuto(venta.fechaHora)} | ${venta.items.map((i) => "${i['emoji']} ${i['tamano']}").join(', ')}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: sePuedeEditar
                            ? () => _confirmarBorradoVenta(fechaObj, venta)
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '⚠️ Día pasado bloqueado. Toca el icono de lápiz arriba para poder borrar ventas.',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. RESUMEN MENSUAL
// -----------------------------------------------------------------------------
class ResumenMesVista extends StatelessWidget {
  final Map<String, List<VentaRegistrada>> ventasPorMes;
  final List<SaborInfo> menuSabores;
  final Map<String, Map<String, Map<String, double>>> lotesPorMes;
  final DateTime mesVisualizado;
  final bool mostrarTotalAcumulado;
  final Function(int) onCambiarMes;
  final List<GastoRegistrado> historialGastos;

  const ResumenMesVista({
    super.key,
    required this.ventasPorMes,
    required this.menuSabores,
    required this.lotesPorMes,
    required this.mesVisualizado,
    required this.mostrarTotalAcumulado,
    required this.onCambiarMes,
    required this.historialGastos,
  });

  String _obtenerClaveMes(DateTime fecha) =>
      "${fecha.year}_${fecha.month.toString().padLeft(2, '0')}";
  String _obtenerClaveDia(DateTime fecha) =>
      "${fecha.year}_${fecha.month.toString().padLeft(2, '0')}_${fecha.day.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    String claveMesVisualizado = _obtenerClaveMes(mesVisualizado);
    List<VentaRegistrada> ventasDelMes =
        ventasPorMes[claveMesVisualizado] ?? [];
    Map<String, Map<String, double>> lotesDelMes =
        lotesPorMes[claveMesVisualizado] ?? {};

    DateTime mesAnterior = DateTime(
      mesVisualizado.year,
      mesVisualizado.month - 1,
    );
    String claveMesAnterior = _obtenerClaveMes(mesAnterior);
    List<VentaRegistrada> ventasMesAnterior =
        ventasPorMes[claveMesAnterior] ?? [];
    List<VentaRegistrada> ventasUltimosDosMeses = [
      ...ventasMesAnterior,
      ...ventasDelMes,
    ];

    double ventaBrutaMes = 0.0;
    double gastoInsumosMes = 0.0;
    double envioAbsorbidoMes = 0.0;
    Set<String> diasLaboradosSet = {};
    int totalTickets = ventasDelMes.length;

    Map<String, int> medianosPorSabor = {};
    Map<String, int> grandesPorSabor = {};
    Map<String, double> ventaBrutaPorSabor = {};

    for (var v in ventasDelMes) {
      ventaBrutaMes += v.total;
      envioAbsorbidoMes += v.envioAbsorbido;
      diasLaboradosSet.add(_obtenerClaveDia(v.fechaHora));

      for (var item in v.items) {
        String sNombre = item['sabor'] ?? '';
        String sTamano = item['tamano'] ?? '';
        double pVenta = (item['precio'] as num).toDouble();

        var saborObj = menuSabores.firstWhere(
          (s) => s.nombre == sNombre || sNombre.contains(s.nombre),
          orElse: () => SaborInfo(
            id: '',
            nombre: sNombre,
            emoji: '',
            color: Colors.white,
            precioMediano: 0,
            precioGrande: 0,
            costoLoteCompleto: 0,
            costoInsumosMediano: 0,
            costoInsumosGrande: 0,
          ),
        );

        ventaBrutaPorSabor[saborObj.nombre] =
            (ventaBrutaPorSabor[saborObj.nombre] ?? 0) + pVenta;

        if (sTamano == 'Mediano') {
          gastoInsumosMes += saborObj.costoInsumosMediano;
          medianosPorSabor[saborObj.nombre] =
              (medianosPorSabor[saborObj.nombre] ?? 0) + 1;
        } else if (sTamano == 'Grande') {
          gastoInsumosMes += saborObj.costoInsumosGrande;
          grandesPorSabor[saborObj.nombre] =
              (grandesPorSabor[saborObj.nombre] ?? 0) + 1;
        }
      }
    }

    double gastoCocinadasMes = 0.0;
    final costoLotePorSabor = <String, double>{};
    lotesDelMes.forEach((dia, mapaLotes) {
      mapaLotes.forEach((saborId, fraccion) {
        var saborObj = menuSabores.firstWhere(
          (s) => s.id == saborId,
          orElse: () => menuSabores.first,
        );
        final costo = saborObj.costoLoteCompleto * fraccion;
        gastoCocinadasMes += costo;
        costoLotePorSabor[saborObj.nombre] =
            (costoLotePorSabor[saborObj.nombre] ?? 0) + costo;
      });
    });

    final gastosBilleteraMes = historialGastos
        .where(
          (g) =>
              g.fechaHora.year == mesVisualizado.year &&
              g.fechaHora.month == mesVisualizado.month,
        )
        .fold<double>(0, (suma, gasto) => suma + gasto.monto);

    double gastoTotalMes =
        gastoCocinadasMes + gastoInsumosMes + envioAbsorbidoMes;
    double gananciaNetaMes = ventaBrutaMes - gastoTotalMes;
    double margenGananciaPromedio = ventaBrutaMes > 0
        ? (gananciaNetaMes / ventaBrutaMes * 100)
        : 0.0;
    final ventasSobreCosto = gastoTotalMes > 0
        ? ventaBrutaMes / gastoTotalMes * 100
        : 0.0;
    double ticketPromedio = totalTickets > 0
        ? (ventaBrutaMes / totalTickets)
        : 0.0;
    int totalDiasLaborados = diasLaboradosSet.length;

    double granTotalVasosEquivalentesMes = 0.0;
    int totalVasosFisicos = 0;
    for (var sabor in menuSabores) {
      int totalMed = medianosPorSabor[sabor.nombre] ?? 0;
      int totalGde = grandesPorSabor[sabor.nombre] ?? 0;
      totalVasosFisicos += totalMed + totalGde;
      granTotalVasosEquivalentesMes += totalMed + (totalGde * 1.66);
    }

    // Gasto de Gas Real / Estimado ($1.5 pesos por vaso)
    double gastoGasEstimado = totalVasosFisicos * 1.5;

    Map<int, double> ventaPorDiaSemana2M = {};
    Map<int, double> ventaPorHora2M = {};
    Map<String, double> ventaBrutaPorSabor2M = {};

    for (var v in ventasUltimosDosMeses) {
      int diaSemana = v.fechaHora.weekday;
      int horaVenta = v.fechaHora.hour;
      ventaPorDiaSemana2M[diaSemana] =
          (ventaPorDiaSemana2M[diaSemana] ?? 0) + v.total;
      ventaPorHora2M[horaVenta] = (ventaPorHora2M[horaVenta] ?? 0) + v.total;

      for (var item in v.items) {
        String sNombre = item['sabor'] ?? '';
        double pVenta = (item['precio'] as num).toDouble();
        var saborObj = menuSabores.firstWhere(
          (s) => s.nombre == sNombre || sNombre.contains(s.nombre),
          orElse: () => SaborInfo(
            id: '',
            nombre: sNombre,
            emoji: '',
            color: Colors.white,
            precioMediano: 0,
            precioGrande: 0,
            costoLoteCompleto: 0,
            costoInsumosMediano: 0,
            costoInsumosGrande: 0,
          ),
        );
        ventaBrutaPorSabor2M[saborObj.nombre] =
            (ventaBrutaPorSabor2M[saborObj.nombre] ?? 0) + pVenta;
      }
    }

    String mejorDiaNombre = "N/A";
    if (ventaPorDiaSemana2M.isNotEmpty) {
      int mejorDiaId = ventaPorDiaSemana2M.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      mejorDiaNombre = Fechas.nombreDiaSemana(mejorDiaId);
    }

    String mejorHoraTexto = "N/A";
    if (ventaPorHora2M.isNotEmpty) {
      int mejorHoraId = ventaPorHora2M.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      mejorHoraTexto = "$mejorHoraId:00 a ${mejorHoraId + 1}:00 hrs";
    }

    String productoEstrella = "N/A";
    if (ventaBrutaPorSabor2M.isNotEmpty) {
      productoEstrella = ventaBrutaPorSabor2M.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    String mesNombreVisualizado = Fechas.nombreMesAnio(mesVisualizado);

    final fechaCorte = DateTime.now();
    final desdeUltimos60 = fechaCorte.subtract(const Duration(days: 60));
    final diasVenta60 = <String, DateTime>{};
    final ventasSabor60 = <String, int>{};
    for (final ventas in ventasPorMes.values) {
      for (final venta in ventas) {
        if (venta.fechaHora.isBefore(desdeUltimos60) ||
            venta.fechaHora.isAfter(fechaCorte)) {
          continue;
        }
        diasVenta60[_obtenerClaveDia(venta.fechaHora)] = venta.fechaHora;
        for (final item in venta.items) {
          final sabor = '${item['sabor'] ?? ''}';
          ventasSabor60[sabor] = (ventasSabor60[sabor] ?? 0) + 1;
        }
      }
    }

    Color colorGananciaNeta;
    if (!mostrarTotalAcumulado) {
      colorGananciaNeta = Colors.white;
    } else {
      colorGananciaNeta = gananciaNetaMes >= 0
          ? Colors.greenAccent
          : Colors.redAccent;
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '📈 Resumen Mensual',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1E293B),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.storefront), text: 'Puesto'),
              Tab(icon: Icon(Icons.delivery_dining), text: 'A domicilio'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: const Color(0xFF0F172A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.cyan,
                      size: 20,
                    ),
                    onPressed: () => onCambiarMes(-1),
                  ),
                  Text(
                    mesNombreVisualizado,
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.cyan,
                      size: 20,
                    ),
                    onPressed:
                        mesVisualizado.month == DateTime.now().month &&
                            mesVisualizado.year == DateTime.now().year
                        ? null
                        : () => onCambiarMes(1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (ventasDelMes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Sin ventas registradas para este mes.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      Card(
                        color: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              const Text(
                                '💰 Resultado estimado del producto',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                mostrarTotalAcumulado
                                    ? '\$${gananciaNetaMes.toStringAsFixed(2)} MXN'
                                    : '\$ • • • • •',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: colorGananciaNeta,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: Colors.white12),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _MiniDatoFinanciero(
                                    label: 'Venta Bruta',
                                    value: mostrarTotalAcumulado
                                        ? '\$${ventaBrutaMes.toStringAsFixed(0)}'
                                        : '• • •',
                                    color: Colors.white,
                                  ),
                                  _MiniDatoFinanciero(
                                    label: 'Costo registrado',
                                    value: mostrarTotalAcumulado
                                        ? '\$${gastoTotalMes.toStringAsFixed(0)}'
                                        : '• • •',
                                    color: Colors.orangeAccent,
                                  ),
                                  _MiniDatoFinanciero(
                                    label: 'Días Laborados',
                                    value: '$totalDiasLaborados días',
                                    color: Colors.cyan,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                mostrarTotalAcumulado
                                    ? 'Ventas / costo registrado: ${ventasSobreCosto.toStringAsFixed(1)}%  ·  Gastos en Billetera aparte: \$${gastosBilleteraMes.toStringAsFixed(0)}'
                                    : 'Ventas / costo registrado: • • •  ·  Gastos en Billetera aparte: • • •',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'El porcentaje compara ventas con costo de lotes, insumos por vaso y envío absorbido. Billetera se muestra aparte para evitar contar dos veces compras ya incluidas en esos costos.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '📊 Promedios y Márgenes:',
                        style: TextStyle(
                          color: Colors.cyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _CardEstadisticaLarga(
                        icon: Icons.trending_up,
                        label: 'Ganancia promedio por día trabajado',
                        value: mostrarTotalAcumulado
                            ? '\$${(totalDiasLaborados > 0 ? gananciaNetaMes / totalDiasLaborados : 0).toStringAsFixed(2)}'
                            : '• • •',
                        colorValue: Colors.greenAccent,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _CardEstadisticaSimple(
                              icon: Icons.percent,
                              label: 'Margen estimado sobre venta',
                              value: mostrarTotalAcumulado
                                  ? '${margenGananciaPromedio.toStringAsFixed(1)}%'
                                  : '• • •',
                              colorValue: Colors.greenAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CardEstadisticaSimple(
                              icon: Icons.receipt_long,
                              label: 'Ticket Promedio (2M)',
                              value: mostrarTotalAcumulado
                                  ? '\$${ticketPromedio.toStringAsFixed(1)}'
                                  : '• • •',
                              colorValue: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'El margen mostrado resta costos de producción registrados, insumos por vaso y envío absorbido; no suma por separado los egresos de Billetera.',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'El resultado resta el costo de todos los lotes cocinados del mes. Como no se registra el producto que queda, este cálculo no separa lo conservado de lo que se desperdició.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '🔥 Gasto de Gas Calculado:',
                        style: TextStyle(
                          color: Colors.cyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _CardEstadisticaLarga(
                        icon: Icons.local_fire_department,
                        label: 'Gasto Sugerido (\$1.5/vaso)',
                        value: mostrarTotalAcumulado
                            ? '\$${gastoGasEstimado.toStringAsFixed(2)} MXN'
                            : '• • •',
                        colorValue: Colors.amberAccent,
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Basado en $totalVasosFisicos vasos totales este mes.',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '🍲 Sugerencia diaria de producción (últimos 60 días)',
                        style: TextStyle(
                          color: Colors.cyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        diasVenta60.isEmpty
                            ? 'Aún no hay ventas suficientes para sugerir cantidades.'
                            : 'Promedio por sabor en sus días de venta programados; solo cuenta días en que el puesto tuvo ventas. La recomendación se redondea hacia arriba.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      ...menuSabores.map((sabor) {
                        final diasOperativos = diasVenta60.values
                            .where((d) => sabor.diasVenta.contains(d.weekday))
                            .length;
                        final promedio = diasOperativos == 0
                            ? 0.0
                            : (ventasSabor60[sabor.nombre] ?? 0) /
                                  diasOperativos;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: sabor.color,
                            child: Text(sabor.emoji),
                          ),
                          title: Text(sabor.nombre),
                          subtitle: Text(
                            '${promedio.toStringAsFixed(1)} vasos por día de venta · ${sabor.diasVenta.map(Fechas.nombreDiaSemana).join(', ')}',
                          ),
                          trailing: Text(
                            '${promedio.ceil()} vasos',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      const Text(
                        '💡 Inteligencia de Venta (Últimos 2 Meses):',
                        style: TextStyle(
                          color: Colors.cyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CardEstadisticaLarga(
                        icon: Icons.star,
                        label: 'Sabor Estrella',
                        value: productoEstrella,
                        colorValue: Colors.amberAccent,
                      ),
                      const SizedBox(height: 10),
                      _CardEstadisticaLarga(
                        icon: Icons.calendar_month,
                        label: 'Día de Más Venta',
                        value: mejorDiaNombre.toUpperCase(),
                        colorValue: Colors.cyan,
                      ),
                      const SizedBox(height: 10),
                      _CardEstadisticaLarga(
                        icon: Icons.access_time_filled,
                        label: 'Hora Pico de Venta',
                        value: mejorHoraTexto,
                        colorValue: Colors.orangeAccent,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '🍿 Ventas y costo de lotes por sabor:',
                        style: TextStyle(
                          color: Colors.cyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...menuSabores.map((sabor) {
                        int totalMed = medianosPorSabor[sabor.nombre] ?? 0;
                        int totalGde = grandesPorSabor[sabor.nombre] ?? 0;
                        double equivalenciaGrandesEnMedianos = totalGde * 1.66;
                        double totalVasosEquivalentes =
                            totalMed + equivalenciaGrandesEnMedianos;

                        final costoCocinado =
                            costoLotePorSabor[sabor.nombre] ?? 0;
                        final ventasSabor =
                            ventaBrutaPorSabor[sabor.nombre] ?? 0;
                        final retornoLote = costoCocinado > 0
                            ? ventasSabor / costoCocinado * 100
                            : 0.0;
                        final insumosVendidos =
                            totalMed * sabor.costoInsumosMediano +
                            totalGde * sabor.costoInsumosGrande;

                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: sabor.color,
                                      radius: 16,
                                      child: Text(
                                        sabor.emoji,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        sabor.nombre,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${totalVasosEquivalentes.toStringAsFixed(1)} vasos eq.',
                                      style: const TextStyle(
                                        color: Colors.cyan,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Divider(color: Colors.white10),
                                const SizedBox(height: 4),
                                Text(
                                  'Ventas: \$${ventasSabor.toStringAsFixed(0)}  ·  Costo de lotes cocinados: \$${costoCocinado.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  costoCocinado > 0
                                      ? 'Ventas / costo de lote: ${retornoLote.toStringAsFixed(1)}%  ·  Saldo antes de otros gastos: \$${(ventasSabor - costoCocinado - insumosVendidos).toStringAsFixed(0)}'
                                      : 'Sin costo de lote registrado este mes',
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(
                            color: Colors.cyan,
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.local_mall,
                                    color: Colors.cyan,
                                    size: 24,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Total Vasos del Mes\n(Equivalentes a Mediano):',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${granTotalVasosEquivalentesMes.toStringAsFixed(1)} eq.',
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                  ResumenDomicilioMesVista(
                    ventas: ventasDelMes,
                    menuSabores: menuSabores,
                    lotesDelMes: lotesDelMes,
                    mostrarTotales: mostrarTotalAcumulado,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResumenDomicilioMesVista extends StatefulWidget {
  final List<VentaRegistrada> ventas;
  final List<SaborInfo> menuSabores;
  final Map<String, Map<String, double>> lotesDelMes;
  final bool mostrarTotales;
  const ResumenDomicilioMesVista({
    super.key,
    required this.ventas,
    required this.menuSabores,
    required this.lotesDelMes,
    required this.mostrarTotales,
  });
  @override
  State<ResumenDomicilioMesVista> createState() =>
      _ResumenDomicilioMesVistaState();
}

class _ResumenDomicilioMesVistaState extends State<ResumenDomicilioMesVista> {
  final sueldoCtrl = TextEditingController(text: '4500');
  @override
  void dispose() {
    sueldoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delivery = widget.ventas
        .where((v) => v.tipoVenta == 'domicilio')
        .toList();
    final puesto = widget.ventas
        .where((v) => v.tipoVenta != 'domicilio')
        .toList();

    double suma(List<VentaRegistrada> list) =>
        list.fold(0, (a, v) => a + v.total);
    double sumaEnviosAbsorbidos(List<VentaRegistrada> list) =>
        list.fold(0, (a, v) => a + v.envioAbsorbido);

    final unidadesTotal = <String, double>{};
    final unidadesDelivery = <String, double>{};
    double costoInsumos = 0;

    for (final venta in widget.ventas) {
      for (final item in venta.items) {
        final nombre = '${item['sabor'] ?? ''}';
        unidadesTotal[nombre] = (unidadesTotal[nombre] ?? 0) + 1;
        if (venta.tipoVenta == 'domicilio') {
          unidadesDelivery[nombre] = (unidadesDelivery[nombre] ?? 0) + 1;
          final sabor = widget.menuSabores
              .where((s) => s.nombre == nombre)
              .firstOrNull;
          if (sabor != null) {
            costoInsumos += item['tamano'] == 'Grande'
                ? sabor.costoInsumosGrande
                : sabor.costoInsumosMediano;
          }
        }
      }
    }

    final costoLotePorSabor = <String, double>{};
    for (final dia in widget.lotesDelMes.values) {
      for (final entry in dia.entries) {
        final sabor = widget.menuSabores
            .where((s) => s.id == entry.key)
            .firstOrNull;
        if (sabor != null) {
          costoLotePorSabor[sabor.nombre] =
              (costoLotePorSabor[sabor.nombre] ?? 0) +
              sabor.costoLoteCompleto * entry.value;
        }
      }
    }

    double lotesAsignados = 0;
    for (final e in costoLotePorSabor.entries) {
      final total = unidadesTotal[e.key] ?? 0;
      if (total > 0) {
        lotesAsignados += e.value * ((unidadesDelivery[e.key] ?? 0) / total);
      }
    }

    double enviosAbsorbidosTotales = sumaEnviosAbsorbidos(delivery);
    final gananciaDelivery =
        suma(delivery) -
        costoInsumos -
        lotesAsignados -
        enviosAbsorbidosTotales;
    final sueldo = double.tryParse(sueldoCtrl.text) ?? 4500;
    final mascara = widget.mostrarTotales;
    double ticketPromedio = delivery.isNotEmpty
        ? suma(delivery) / delivery.length
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Estadísticas de pedidos a domicilio',
          style: TextStyle(
            color: Colors.cyanAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        _CardEstadisticaLarga(
          icon: Icons.storefront,
          label: 'Ventas Puesto · ${puesto.length} uds',
          value: mascara ? '\$${suma(puesto).toStringAsFixed(0)}' : '• • •',
          colorValue: Colors.cyan,
        ),
        _CardEstadisticaLarga(
          icon: Icons.delivery_dining,
          label: 'Ventas Domicilio · ${delivery.length} uds',
          value: mascara ? '\$${suma(delivery).toStringAsFixed(0)}' : '• • •',
          colorValue: Colors.orangeAccent,
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF1E293B),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Desglose Financiero Domicilio:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ticket Promedio Domicilio:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      mascara
                          ? '\$${ticketPromedio.toStringAsFixed(1)}'
                          : '• • •',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Gastos Envío Absorbidos:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      mascara
                          ? '-\$${enviosAbsorbidosTotales.toStringAsFixed(0)}'
                          : '• • •',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 5),
                const Text(
                  'Aporte del domicilio frente al sueldo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextField(
                  controller: sueldoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Sueldo mensual esperado',
                    prefixText: '\$',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Text(
                  mascara
                      ? 'Ganancia Neta (Libre) Domicilio: \$${gananciaDelivery.toStringAsFixed(0)}'
                      : 'Ganancia Neta (Libre) Domicilio: • • •',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  mascara
                      ? (gananciaDelivery >= sueldo
                            ? 'La estimación cubre la meta mensual.'
                            : 'Faltarían \$${(sueldo - gananciaDelivery).toStringAsFixed(0)} para cubrirla.')
                      : '• • •',
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ya se están restando insumos, fracción de lote y envíos absorbidos.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniDatoFinanciero extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniDatoFinanciero({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _CardEstadisticaSimple extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color colorValue;
  const _CardEstadisticaSimple({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorValue,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: Colors.cyan, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: colorValue,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardEstadisticaLarga extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color colorValue;
  const _CardEstadisticaLarga({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorValue,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: colorValue, size: 26),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Text(
          value,
          style: TextStyle(
            color: colorValue,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. PEDIDOS DOMICILIO
// -----------------------------------------------------------------------------
class PedidosDomicilioVista extends StatefulWidget {
  final List<SaborInfo> menuSabores;
  final List<ClienteDomicilio> clientes;
  final List<PedidoDomicilio> pedidos;
  final String telefonoRepartidor;
  final double costoEnvioDefault;
  final Map<String, String> plantillasMensajes;
  final ValueChanged<PedidoDomicilio> onGuardarPedido;
  final ValueChanged<PedidoDomicilio> onMarcarEnCamino;
  final ValueChanged<PedidoDomicilio> onBorrarPedido;
  const PedidosDomicilioVista({
    super.key,
    required this.menuSabores,
    required this.clientes,
    required this.pedidos,
    required this.telefonoRepartidor,
    required this.costoEnvioDefault,
    required this.plantillasMensajes,
    required this.onGuardarPedido,
    required this.onMarcarEnCamino,
    required this.onBorrarPedido,
  });
  @override
  State<PedidosDomicilioVista> createState() => _PedidosDomicilioVistaState();
}

class _PedidosDomicilioVistaState extends State<PedidosDomicilioVista> {
  String _mensajePlantilla(String clave, Map<String, String> valores) {
    var mensaje =
        widget.plantillasMensajes[clave] ??
        plantillasDomicilioPredeterminadas[clave] ??
        '';
    for (final entrada in valores.entries) {
      mensaje = mensaje.replaceAll('{{${entrada.key}}}', entrada.value);
    }
    return mensaje;
  }

  Color _colorEstado(String estado) => switch (estado) {
    'Pendiente' => Colors.redAccent,
    'Confirmado' || 'Listo' => Colors.orangeAccent,
    'En camino' => Colors.greenAccent,
    'Cancelado' => Colors.grey,
    _ => Colors.blueGrey,
  };

  int _ordenEstado(String estado) => switch (estado) {
    'Pendiente' => 0,
    'Confirmado' => 1,
    'Listo' => 2,
    'En camino' => 3,
    'Cancelado' => 4,
    _ => 5,
  };

  Future<bool> _abrirWhatsApp(String telefono, String mensaje) async {
    var tel = telefono.replaceAll(RegExp(r'\D'), '');
    if (tel.length == 10) tel = '52$tel';
    if (tel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta teléfono de destino.')),
      );
      return false;
    }
    final uri = Uri.parse(
      'https://wa.me/$tel?text=${Uri.encodeComponent(mensaje)}',
    );
    final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
      );
    }
    return abierto;
  }

  String _maps(ClienteDomicilio c) {
    final q = '${c.calle}, ${c.colonia}, San Luis de la Paz, Guanajuato';
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}';
  }

  String _normalizarTexto(String texto) => texto
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n');

  Future<void> _importarMensaje() async {
    final ctrl = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Importar mensaje de WhatsApp'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: ctrl,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              hintText: 'Pega aquí el mensaje completo que envió el cliente',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('IMPORTAR'),
          ),
        ],
      ),
    );
    if (texto == null || texto.trim().isEmpty) return;
    try {
      final pedido = _parsearMensaje(texto);
      widget.onGuardarPedido(pedido);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido importado como pendiente de confirmar.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No pude interpretar el mensaje: $e')),
        );
      }
    }
  }

  PedidoDomicilio _parsearMensaje(String texto) {
    String campo(String key) {
      final m = RegExp(
        '(?:\\*${RegExp.escape(key)}:?\\*|${RegExp.escape(key)}:)\\s*([^\\n]+)',
        caseSensitive: false,
      ).firstMatch(texto);
      return m?.group(1)?.replaceAll('*', '').trim() ?? '';
    }

    final nombre = campo('Nombre'), tel = campo('Teléfono');
    final dir = campo('Dirección');
    if (nombre.isEmpty || tel.isEmpty || dir.isEmpty)
      throw FormatException('faltan nombre, teléfono o dirección');
    final partes = dir.split(
      RegExp(r',\s*(?:Col\.?\s*)', caseSensitive: false),
    );
    final calleNumero = partes.first.trim();
    final colonia = partes.length > 1 ? partes[1].trim() : '';
    final numMatch = RegExp(
      r'(?:#|num(?:ero)?\.?\s*)([\w-]+)|\s+(\d+[A-Za-z]?)$',
      caseSensitive: false,
    ).firstMatch(calleNumero);
    final numero = numMatch?.group(1) ?? numMatch?.group(2) ?? '';
    final calle = numMatch == null
        ? calleNumero
        : calleNumero.replaceRange(numMatch.start, numMatch.end, '').trim();
    final refs = campo('Referencias');
    final nota = campo('Nota');
    final items = <Map<String, dynamic>>[];
    final re = RegExp(
      r'^\s*#\d+\s+(.+?)\s*\((Mediano|Grande)\)\s*:\s*(.+)$',
      multiLine: true,
      caseSensitive: false,
    );

    for (final m in re.allMatches(texto)) {
      final nombreSabor = m.group(1)!.trim(),
          tamano = m.group(2)!.toLowerCase().startsWith('med')
              ? 'Mediano'
              : 'Grande';
      final tokens = _normalizarTexto(nombreSabor)
          .split(RegExp(r'[^a-z0-9]+'))
          .where((t) => t.length > 3)
          .toSet();
      final sabor = widget.menuSabores.where((s) {
        final normal = _normalizarTexto(s.nombre);
        return normal.contains(_normalizarTexto(nombreSabor)) ||
            _normalizarTexto(nombreSabor).contains(normal) ||
            normal.split(RegExp(r'[^a-z0-9]+')).any(tokens.contains);
      }).firstOrNull;
      final precio = sabor == null
          ? 0.0
          : (tamano == 'Mediano' ? sabor.precioMediano : sabor.precioGrande);
      items.add({
        'sabor': nombreSabor,
        'tamano': tamano,
        'precio': precio,
        'detalles': m.group(3)!.trim(),
      });
    }
    if (items.isEmpty)
      throw FormatException(
        'no encontré productos con el formato de la página de pedidos',
      );
    final subtotalMatch = RegExp(
      r'Subtotal:\s*\$\s*([\d.]+)',
      caseSensitive: false,
    ).firstMatch(texto);
    final envioMatch = RegExp(
      r'Envío:\s*(?:\$\s*([\d.]+)|(GRATIS))',
      caseSensitive: false,
    ).firstMatch(texto);

    final subtotal = subtotalMatch == null
        ? items.fold<double>(0, (a, i) => a + (i['precio'] as num).toDouble())
        : double.parse(subtotalMatch.group(1)!);

    // Evaluamos envío gratis
    double envioFinal = 0.0;
    double envioAbsorbidoFinal = 0.0;
    if (subtotal >= 220.0) {
      envioFinal = 0.0;
      envioAbsorbidoFinal = widget.costoEnvioDefault;
    } else {
      envioFinal = envioMatch == null || envioMatch.group(2) != null
          ? 0.0
          : double.tryParse(envioMatch.group(1) ?? '') ??
                widget.costoEnvioDefault;
      envioAbsorbidoFinal = 0.0;
    }

    return PedidoDomicilio(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      fechaHora: DateTime.now(),
      cliente: ClienteDomicilio(
        telefono: tel,
        nombre: nombre,
        calle: calle,
        numero: numero,
        colonia: colonia,
        referencias: refs,
      ),
      items: items,
      subtotal: subtotal,
      envio: envioFinal,
      estado: 'Pendiente',
      faltantes: const [],
      nota: nota,
      envioAbsorbido: envioAbsorbidoFinal,
    );
  }

  Future<void> _nuevoManual() async {
    final result = await showDialog<PedidoDomicilio>(
      context: context,
      builder: (_) => _EditorPedidoDomicilio(
        menu: widget.menuSabores,
        clientes: widget.clientes,
        costoEnvioDefault: widget.costoEnvioDefault,
      ),
    );
    if (result != null) {
      widget.onGuardarPedido(result);
    }
  }

  Future<void> _faltantes(PedidoDomicilio p) async {
    final sel = <String>{...p.faltantes};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Marcar productos faltantes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: p.items.map((i) {
              final label = '${i['sabor']} (${i['tamano']})';
              return CheckboxListTile(
                title: Text(label),
                value: sel.contains(label),
                onChanged: (v) => setD(() {
                  if (v == true) {
                    sel.add(label);
                  } else {
                    sel.remove(label);
                  }
                }),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final updated = p.copyWith(faltantes: sel.toList());
    widget.onGuardarPedido(updated);
    if (sel.isNotEmpty) {
      final msg = _mensajePlantilla('faltantes', {
        'nombre': p.cliente.nombre,
        'faltantes': sel.join(', '),
      });
      await _abrirWhatsApp(p.cliente.telefono, msg);
    }
  }

  Future<void> _editarPedido(PedidoDomicilio p) async {
    final r = await showDialog<PedidoDomicilio>(
      context: context,
      builder: (_) => _EditorPedidoDomicilio(
        menu: widget.menuSabores,
        clientes: widget.clientes,
        inicial: p,
        costoEnvioDefault: widget.costoEnvioDefault,
      ),
    );
    if (r != null) {
      widget.onGuardarPedido(r);
    }
  }

  Future<void> _cancelarPedido(PedidoDomicilio p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Cancelar pedido'),
        content: Text(
          '¿Quieres marcar como cancelado el pedido de ${p.cliente.nombre}? No se registrará como venta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('VOLVER'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CANCELAR PEDIDO'),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.onGuardarPedido(p.copyWith(estado: 'Cancelado'));
    }
  }

  Future<void> _borrarPedido(PedidoDomicilio p) async {
    final primera = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('¿Borrar pedido?'),
        content: Text('Se eliminará el pedido de ${p.cliente.nombre}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('VOLVER'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CONTINUAR'),
          ),
        ],
      ),
    );
    if (primera != true || !mounted) return;
    final segunda = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Confirma el borrado'),
        content: Text(
          p.estado == 'En camino'
              ? 'Si se puede identificar sin ambigüedad, también se quitará del total la venta vinculada de \$${p.total.toStringAsFixed(0)}. Esta acción no se puede deshacer.'
              : 'Esta acción no se puede deshacer. Si se canceló en la vida real, usa “Cancelar pedido” para conservar el registro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('NO BORRAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SÍ, BORRAR DEFINITIVAMENTE'),
          ),
        ],
      ),
    );
    if (segunda == true) widget.onBorrarPedido(p);
  }

  Future<void> _confirmar(PedidoDomicilio p) async {
    final abierto = await _abrirWhatsApp(
      p.cliente.telefono,
      _mensajePlantilla('confirmacion', {
        'nombre': p.cliente.nombre,
        'total': p.total.toStringAsFixed(0),
      }),
    );
    widget.onGuardarPedido(
      p.copyWith(estado: 'Confirmado', confirmacionAbierta: abierto),
    );
  }

  void _marcarListo(PedidoDomicilio p) {
    widget.onGuardarPedido(p.copyWith(estado: 'Listo', marcadoListo: true));
  }

  Future<void> _avisarRepartidor(PedidoDomicilio p) async {
    if (widget.telefonoRepartidor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registra el teléfono del repartidor en Ajustes primero.',
          ),
        ),
      );
      return;
    }
    final lineas = p.items
        .map((i) => '• ${i['sabor']} (${i['tamano']}): ${i['detalles'] ?? ''}')
        .join('\n');
    final msg = _mensajePlantilla('repartidor', {
      'nombre': p.cliente.nombre,
      'telefono': p.cliente.telefono,
      'direccion':
          '${p.cliente.calle} ${p.cliente.numero}, Col. ${p.cliente.colonia}',
      'referencias': p.cliente.referencias,
      'nota': p.nota,
      'pedido': lineas,
      'total': p.total.toStringAsFixed(0),
      'maps': _maps(p.cliente),
    });
    final abierto = await _abrirWhatsApp(widget.telefonoRepartidor, msg);
    if (abierto) {
      widget.onGuardarPedido(p.copyWith(avisoRepartidorAbierto: true));
    }
  }

  Future<void> _enCamino(PedidoDomicilio p) async {
    final abierto = await _abrirWhatsApp(
      p.cliente.telefono,
      _mensajePlantilla('enCamino', {'nombre': p.cliente.nombre}),
    );
    widget.onMarcarEnCamino(
      p.copyWith(avisoEnCaminoAbierto: abierto || p.avisoEnCaminoAbierto),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pedidosOrdenados = [...widget.pedidos]
      ..sort((a, b) {
        final porEstado = _ordenEstado(a.estado)
            .compareTo(_ordenEstado(b.estado));
        if (porEstado != 0) return porEstado;
        return b.fechaHora.compareTo(a.fechaHora);
      });
    final cancelados = widget.pedidos
        .where((p) => p.estado == 'Cancelado')
        .length;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.black,
        onPressed: _nuevoManual,
        icon: const Icon(Icons.add),
        label: const Text('NUEVO PEDIDO'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '🛵 Pedidos a domicilio',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                    ),
                  ),
                ),
                Chip(
                  label: Text('Cancelados: $cancelados'),
                  avatar: const Icon(Icons.cancel_outlined, size: 16),
                ),
              ],
            ),
          ),
          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Importar mensaje del cliente',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pega el mensaje que recibiste por WhatsApp. El pedido quedará pendiente de revisar y confirmar.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _importarMensaje,
                      icon: const Icon(Icons.content_paste),
                      label: const Text('PEGAR / IMPORTAR MENSAJE'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (pedidosOrdenados.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'No hay pedidos registrados.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ...pedidosOrdenados.map(
            (p) => Card(
              color: Color.lerp(
                const Color(0xFF1E293B),
                _colorEstado(p.estado),
                0.12,
              ),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _colorEstado(p.estado), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${p.cliente.nombre} · ${p.estado}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: _colorEstado(p.estado),
                            ),
                          ),
                        ),
                        Text(
                          '\$${p.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${p.cliente.telefono} · ${p.cliente.calle} ${p.cliente.numero}, ${p.cliente.colonia}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '${Fechas.diaMesAnio(p.fechaHora)} · ${Fechas.horaMinuto(p.fechaHora)}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    if (p.cliente.referencias.isNotEmpty)
                      Text(
                        'Ref: ${p.cliente.referencias}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    const Divider(),
                    ...p.items.map(
                      (i) => Text(
                        '• ${i['sabor']} ${i['tamano']}: ${i['detalles'] ?? ''}',
                      ),
                    ),
                    if (p.faltantes.isNotEmpty)
                      Text(
                        'Faltantes: ${p.faltantes.join(', ')}',
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    Wrap(
                      spacing: 6,
                      children: [
                        _indicadorAccion('Confirmación', p.confirmacionAbierta),
                        _indicadorAccion('Listo', p.marcadoListo),
                        _indicadorAccion(
                          'Aviso repartidor',
                          p.avisoRepartidorAbierto,
                        ),
                        _indicadorAccion('En camino', p.avisoEnCaminoAbierto),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (p.estado != 'En camino' && p.estado != 'Cancelado')
                          TextButton(
                            onPressed: () => _editarPedido(p),
                            child: const Text('EDITAR'),
                          ),
                        if (p.estado == 'Pendiente' ||
                            p.estado == 'Confirmado' ||
                            p.estado == 'Listo')
                          TextButton(
                            onPressed: () => _faltantes(p),
                            child: const Text('FALTANTE'),
                          ),
                        TextButton.icon(
                          onPressed: () => _borrarPedido(p),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 17,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            'BORRAR',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                        if (p.estado == 'Pendiente')
                          ElevatedButton(
                            onPressed: () => _confirmar(p),
                            child: const Text('CONFIRMAR'),
                          ),
                        if (p.estado == 'Confirmado')
                          ElevatedButton(
                            onPressed: () => _marcarListo(p),
                            child: const Text('MARCAR COMO LISTO'),
                          ),
                        if (p.estado == 'Listo')
                          ElevatedButton(
                            onPressed: () => _avisarRepartidor(p),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.avisoRepartidorAbierto
                                  ? Colors.green
                                  : null,
                              foregroundColor: p.avisoRepartidorAbierto
                                  ? Colors.white
                                  : null,
                            ),
                            child: const Text('AVISAR REPARTIDOR'),
                          ),
                        if (p.estado == 'Listo')
                          ElevatedButton.icon(
                            onPressed: () => _enCamino(p),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.avisoEnCaminoAbierto
                                  ? Colors.green
                                  : null,
                              foregroundColor: p.avisoEnCaminoAbierto
                                  ? Colors.white
                                  : null,
                            ),
                            icon: const Icon(Icons.delivery_dining),
                            label: const Text('SALIO / EN CAMINO'),
                          ),
                        if (p.estado == 'Pendiente' ||
                            p.estado == 'Confirmado' ||
                            p.estado == 'Listo')
                          TextButton(
                            onPressed: () => _cancelarPedido(p),
                            child: const Text(
                              'CANCELAR PEDIDO',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicadorAccion(String texto, bool completado) => Chip(
    visualDensity: VisualDensity.compact,
    avatar: Icon(
      completado ? Icons.check_circle : Icons.radio_button_unchecked,
      size: 16,
      color: completado ? Colors.greenAccent : Colors.white38,
    ),
    label: Text(texto, style: const TextStyle(fontSize: 11)),
    backgroundColor: completado
        ? Colors.green.withValues(alpha: 0.18)
        : Colors.white10,
    side: BorderSide(color: completado ? Colors.greenAccent : Colors.white24),
  );
}

class _EditorPedidoDomicilio extends StatefulWidget {
  final List<SaborInfo> menu;
  final List<ClienteDomicilio> clientes;
  final PedidoDomicilio? inicial;
  final double costoEnvioDefault;
  const _EditorPedidoDomicilio({
    required this.menu,
    required this.clientes,
    this.inicial,
    required this.costoEnvioDefault,
  });
  @override
  State<_EditorPedidoDomicilio> createState() => _EditorPedidoDomicilioState();
}

class _EditorPedidoDomicilioState extends State<_EditorPedidoDomicilio> {
  late final TextEditingController tel, nombre, calle, numero, colonia, refs;
  late final FocusNode focoTelefono;
  late List<Map<String, dynamic>> items;
  late String? saborId;
  String tamano = 'Mediano';
  bool panela = true;
  bool molido = true;
  bool huesito = false;
  String nivelMantequilla = 'Picosito';
  String limon = 'Con limón';
  String chile = 'Picosito';
  final detalle = TextEditingController();
  late final TextEditingController envioCtrl;
  late final TextEditingController notaCtrl;
  late double envio;
  double envioAbsorbidoTemporal = 0.0;

  @override
  void initState() {
    super.initState();
    final p = widget.inicial;
    final c = p?.cliente;
    tel = TextEditingController(text: c?.telefono ?? '');
    focoTelefono = FocusNode();
    nombre = TextEditingController(text: c?.nombre ?? '');
    calle = TextEditingController(text: c?.calle ?? '');
    numero = TextEditingController(text: c?.numero ?? '');
    colonia = TextEditingController(text: c?.colonia ?? '');
    refs = TextEditingController(text: c?.referencias ?? '');
    items = p?.items.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    saborId = widget.menu.isEmpty ? null : widget.menu.first.id;
    envio = p?.envio ?? widget.costoEnvioDefault;
    envioAbsorbidoTemporal = p?.envioAbsorbido ?? 0.0;
    envioCtrl = TextEditingController(text: envio.toStringAsFixed(0));
    notaCtrl = TextEditingController(text: p?.nota ?? '');
  }

  @override
  void dispose() {
    tel.dispose();
    focoTelefono.dispose();
    nombre.dispose();
    calle.dispose();
    numero.dispose();
    colonia.dispose();
    refs.dispose();
    detalle.dispose();
    envioCtrl.dispose();
    notaCtrl.dispose();
    super.dispose();
  }

  double get subtotal =>
      items.fold<double>(0, (a, i) => a + (i['precio'] as num).toDouble());

  void _recalcularEnvio() {
    if (subtotal >= 220) {
      envio = 0;
      envioAbsorbidoTemporal = widget.costoEnvioDefault;
    } else {
      envio = widget.costoEnvioDefault;
      envioAbsorbidoTemporal = 0;
    }
    envioCtrl.text = envio.toStringAsFixed(0);
  }

  String _detalleDinamico(SaborInfo sabor) {
    String resultado;
    if (sabor.llevaQuesos) {
      final quesos = [if (panela) 'Queso Panela', if (molido) 'Queso Molido'];
      resultado =
          '${nivelMantequilla} (${quesos.isEmpty ? 'Sin queso' : quesos.join(' y ')})';
    } else {
      resultado = '$limon, $chile';
      if (sabor.llevaHuesito && tamano == 'Grande' && huesito) {
        resultado += ' + Huesito de espinazo';
      }
    }
    if (detalle.text.trim().isNotEmpty) {
      resultado += ' · ${detalle.text.trim()}';
    }
    return resultado;
  }

  Widget _opciones(
    List<String> opciones,
    String valor,
    ValueChanged<String> alElegir,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      children: opciones
          .map(
            (opcion) => ChoiceChip(
              label: Text(opcion),
              selected: valor == opcion,
              onSelected: (_) => setState(() => alElegir(opcion)),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sabores = widget.menu;
    final s = sabores.where((x) => x.id == saborId).firstOrNull;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(widget.inicial == null ? 'Nuevo pedido' : 'Editar pedido'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Autocompletado de Clientes
              RawAutocomplete<ClienteDomicilio>(
                textEditingController: tel,
                focusNode: focoTelefono,
                optionsBuilder: (TextEditingValue t) {
                  if (t.text.isEmpty)
                    return const Iterable<ClienteDomicilio>.empty();
                  final q = t.text.replaceAll(RegExp(r'\D'), '');
                  if (q.length < 4) {
                    return const Iterable<ClienteDomicilio>.empty();
                  }
                  return widget.clientes
                      .where(
                        (c) => c.telefono
                            .replaceAll(RegExp(r'\D'), '')
                            .startsWith(q),
                      )
                      .take(8);
                },
                displayStringForOption: (c) => c.telefono,
                onSelected: (ClienteDomicilio selection) {
                  tel.text = selection.telefono;
                  nombre.text = selection.nombre;
                  calle.text = selection.calle;
                  numero.text = selection.numero;
                  colonia.text = selection.colonia;
                  refs.text = selection.referencias;
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          hintText: 'Escribe los primeros 4 dígitos...',
                        ),
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      color: const Color(0xFF1E293B),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 200,
                          maxWidth: 300,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final ClienteDomicilio option = options.elementAt(
                              index,
                            );
                            return ListTile(
                              title: Text(
                                '${option.telefono} - ${option.nombre}',
                              ),
                              subtitle: Text(
                                '${option.calle} ${option.numero}, ${option.colonia}',
                              ),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              TextField(
                controller: nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: calle,
                      decoration: const InputDecoration(labelText: 'Calle'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: numero,
                      decoration: const InputDecoration(labelText: 'Número'),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: colonia,
                decoration: const InputDecoration(labelText: 'Colonia'),
              ),
              TextField(
                controller: refs,
                decoration: const InputDecoration(labelText: 'Referencias'),
              ),
              TextField(
                controller: notaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nota del cliente (opcional)',
                ),
              ),
              const Divider(),
              if (sabores.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Selecciona el sabor'),
                    ),
                    Wrap(
                      spacing: 6,
                      children: sabores
                          .map(
                            (x) => ChoiceChip(
                              label: Text('${x.emoji} ${x.nombre}'),
                              selected: saborId == x.id,
                              onSelected: (_) => setState(() => saborId = x.id),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Tamaño'),
                  ),
                  Wrap(
                    spacing: 8,
                    children: ['Mediano', 'Grande']
                        .map(
                          (x) => ChoiceChip(
                            label: Text(x),
                            selected: tamano == x,
                            onSelected: (_) => setState(() => tamano = x),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              if (s != null && s.llevaQuesos) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Quesos'),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    FilterChip(
                      label: const Text('Queso panela'),
                      selected: panela,
                      onSelected: (v) => setState(() => panela = v),
                    ),
                    FilterChip(
                      label: const Text('Queso molido'),
                      selected: molido,
                      onSelected: (v) => setState(() => molido = v),
                    ),
                  ],
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Nivel de picante'),
                ),
                _opciones(
                  const ['Sin chilito', 'Picosito', 'Picosón', 'Picosote'],
                  nivelMantequilla,
                  (v) => nivelMantequilla = v,
                ),
              ],
              if (s != null && s.llevaLimon) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Limón'),
                ),
                _opciones(
                  const [
                    'Con limón',
                    'Limón extra',
                    'Limón aparte',
                    'Sin limón',
                  ],
                  limon,
                  (v) => limon = v,
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Chile'),
                ),
                _opciones(
                  const [
                    'Sin chile',
                    'Chilito que no pica',
                    'Picosito',
                    'Picosón',
                    'Picosote',
                    'Chile aparte',
                  ],
                  chile,
                  (v) => chile = v,
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    limon = 'Limón aparte';
                    chile = 'Chile aparte';
                  }),
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Todo aparte'),
                ),
              ],
              if (s != null && s.llevaHuesito && tamano == 'Grande')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Agregar huesito de espinazo'),
                  value: huesito,
                  onChanged: (v) => setState(() => huesito = v),
                ),
              TextField(
                controller: detalle,
                decoration: const InputDecoration(
                  labelText: 'Nota especial (opcional)',
                ),
              ),
              if (s != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      final precio = tamano == 'Mediano'
                          ? s.precioMediano
                          : s.precioGrande;
                      setState(() {
                        items.add({
                          'sabor': s.nombre,
                          'tamano': tamano,
                          'precio': precio,
                          'detalles': _detalleDinamico(s),
                        });
                        _recalcularEnvio();
                      });
                      detalle.clear();
                      setState(() {
                        panela = true;
                        molido = true;
                        huesito = false;
                        nivelMantequilla = 'Picosito';
                        limon = 'Con limón';
                        chile = 'Picosito';
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: Text(
                      'Agregar · \$${(tamano == 'Mediano' ? s.precioMediano : s.precioGrande).toStringAsFixed(0)}',
                    ),
                  ),
                ),
              ...items.asMap().entries.map(
                (e) => ListTile(
                  dense: true,
                  title: Text('${e.value['sabor']} ${e.value['tamano']}'),
                  subtitle: Text('${e.value['detalles'] ?? ''}'),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => setState(() {
                      items.removeAt(e.key);
                      _recalcularEnvio();
                    }),
                  ),
                ),
              ),
              TextField(
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Costo de envío (Forzar Manual)',
                  prefixText: '\$',
                ),
                controller: envioCtrl,
                onChanged: (v) {
                  setState(() {
                    envio = double.tryParse(v) ?? widget.costoEnvioDefault;
                    // Si cambian manual el envío, no marcamos que lo absorbimos a menos que sea 0 manual.
                    envioAbsorbidoTemporal = envio == 0 && subtotal >= 220
                        ? widget.costoEnvioDefault
                        : 0.0;
                  });
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: \$${(subtotal + envio).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: () => _guardar(context),
          child: const Text('GUARDAR PENDIENTE'),
        ),
      ],
    );
  }

  void _guardar(BuildContext context) {
    if (nombre.text.trim().isEmpty ||
        tel.text.trim().isEmpty ||
        calle.text.trim().isEmpty ||
        colonia.text.trim().isEmpty ||
        items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa cliente, dirección y agrega al menos un producto.',
          ),
        ),
      );
      return;
    }
    final cliente = ClienteDomicilio(
      telefono: tel.text.trim(),
      nombre: nombre.text.trim(),
      calle: calle.text.trim(),
      numero: numero.text.trim(),
      colonia: colonia.text.trim(),
      referencias: refs.text.trim(),
    );
    Navigator.pop(
      context,
      PedidoDomicilio(
        id:
            widget.inicial?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        fechaHora: widget.inicial?.fechaHora ?? DateTime.now(),
        cliente: cliente,
        items: items,
        subtotal: subtotal,
        envio: envio,
        estado: widget.inicial?.estado ?? 'Pendiente',
        faltantes: widget.inicial?.faltantes ?? const [],
        nota: notaCtrl.text.trim(),
        envioAbsorbido: envioAbsorbidoTemporal,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6. PRODUCCIÓN Y SIMULADOR
// -----------------------------------------------------------------------------
class ProduccionVista extends StatefulWidget {
  final List<SaborInfo> menuSabores;
  const ProduccionVista({super.key, required this.menuSabores});
  @override
  State<ProduccionVista> createState() => _ProduccionVistaState();
}

class _ProduccionVistaState extends State<ProduccionVista> {
  final Map<String, double> lotes = {};
  final Map<String, int> medianos = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ProduccionVista oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controllers.forEach((k, v) => v.dispose());
    super.dispose();
  }

  void _sync() {
    for (final sabor in widget.menuSabores) {
      lotes.putIfAbsent(sabor.id, () => 0);
      medianos.putIfAbsent(sabor.id, () => 0);
      if (!_controllers.containsKey(sabor.id)) {
        _controllers[sabor.id] = TextEditingController(
          text: (medianos[sabor.id] ?? 0).toString(),
        );
      }
    }
  }

  void _fijarLote(String id, double frac) {
    setState(() => lotes[id] = frac);
  }

  void _cambiarMedianos(String id, int cambio) {
    setState(() {
      int n = ((medianos[id] ?? 0) + cambio).clamp(0, 9999);
      medianos[id] = n;
      _controllers[id]?.text = n.toString();
    });
  }

  void _setMedianosManual(String id, int n) {
    setState(() {
      medianos[id] = n.clamp(0, 9999);
    });
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    double costoProduccion = 0;
    double gananciaVenta = 0;
    for (final sabor in widget.menuSabores) {
      costoProduccion += sabor.costoLoteCompleto * (lotes[sabor.id] ?? 0);
      gananciaVenta +=
          (medianos[sabor.id] ?? 0) *
          (sabor.precioMediano - sabor.costoInsumosMediano);
    }
    final gananciaNeta = gananciaVenta - costoProduccion;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🍲 Simulador de evento'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ajusta lo que vas a cocinar y cuántos vasos esperas vender. La estimación cambia en tiempo real sin modificar tus registros diarios.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ...widget.menuSabores.map((sabor) {
                    final fraccionActual = lotes[sabor.id] ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${sabor.emoji} ${sabor.nombre}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Text(
                                'Ollas: ',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [0.0, 0.33, 0.5, 1.0, 2.0, 3.0].map((
                                      fraccion,
                                    ) {
                                      bool sel = fraccionActual == fraccion;
                                      String lbl = fraccion == 0.0
                                          ? '❌ 0'
                                          : (fraccion == 0.33
                                                ? '⅓'
                                                : (fraccion == 0.5
                                                      ? '½'
                                                      : (fraccion == 1.0
                                                            ? '🟢 1'
                                                            : '${fraccion.toInt()}')));
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: InkWell(
                                          onTap: () =>
                                              _fijarLote(sabor.id, fraccion),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: sel
                                                  ? Colors.cyan
                                                  : const Color(0xFF0F172A),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: sel
                                                    ? Colors.white
                                                    : Colors.white24,
                                              ),
                                            ),
                                            child: Text(
                                              lbl,
                                              style: TextStyle(
                                                color: sel
                                                    ? Colors.black
                                                    : Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Vasos M a vender:',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _cambiarMedianos(sabor.id, -1),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              SizedBox(
                                width: 50,
                                child: TextField(
                                  controller: _controllers[sabor.id],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                  ),
                                  onChanged: (v) => _setMedianosManual(
                                    sabor.id,
                                    int.tryParse(v) ?? 0,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _cambiarMedianos(sabor.id, 1),
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.cyanAccent,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12),
                        ],
                      ),
                    );
                  }),
                  Text(
                    'Ganancia por vasos, después de insumos: \$${gananciaVenta.toStringAsFixed(2)}',
                  ),
                  Text(
                    'Costo de lo cocinado: \$${costoProduccion.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Ganancia neta esperada: \$${gananciaNeta.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: gananciaNeta >= 0
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 7. AJUSTES
// -----------------------------------------------------------------------------
class AjustesVista extends StatelessWidget {
  final List<SaborInfo> menuSabores;
  final List<Color> paletaColores;
  final double nivelTextoMostrador;
  final double nivelTextoTotal;
  final double nivelTextoHistorial;
  final double costoEnvioDefault;
  final String telefonoRepartidor;
  final Map<String, String> plantillasMensajes;
  final bool mostrarBilletera;
  final ValueChanged<bool> onCambiarMostrarBilletera;
  final ValueChanged<Map<String, String>> onGuardarPlantillas;
  final ValueChanged<double> onCambiarNivelMostrador;
  final ValueChanged<double> onCambiarNivelTotal;
  final ValueChanged<double> onCambiarNivelHistorial;
  final ValueChanged<double> onCambiarCostoEnvio;
  final ValueChanged<String> onCambiarTelefonoRepartidor;
  final Function(SaborInfo) onGuardarSabor;
  final Function(String) onEliminarSabor;
  final VoidCallback onExportar;
  final VoidCallback onImportar;

  const AjustesVista({
    super.key,
    required this.menuSabores,
    required this.paletaColores,
    required this.nivelTextoMostrador,
    required this.nivelTextoTotal,
    required this.nivelTextoHistorial,
    required this.costoEnvioDefault,
    required this.telefonoRepartidor,
    required this.plantillasMensajes,
    required this.mostrarBilletera,
    required this.onCambiarMostrarBilletera,
    required this.onGuardarPlantillas,
    required this.onCambiarNivelMostrador,
    required this.onCambiarNivelTotal,
    required this.onCambiarNivelHistorial,
    required this.onCambiarCostoEnvio,
    required this.onCambiarTelefonoRepartidor,
    required this.onGuardarSabor,
    required this.onEliminarSabor,
    required this.onExportar,
    required this.onImportar,
  });

  void _abrirModalEditar(BuildContext context, SaborInfo? sabor) {
    showDialog(
      context: context,
      builder: (context) => _DialogoEditarSabor(
        sabor: sabor,
        paletaColores: paletaColores,
        onGuardar: onGuardarSabor,
      ),
    );
  }

  void _confirmarEliminacion(BuildContext context, SaborInfo sabor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 26,
            ),
            SizedBox(width: 8),
            Text(
              '¿Estás seguro?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Vas a eliminar permanentemente "${sabor.nombre}". Esto no borrará las ventas pasadas.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              onEliminarSabor(sabor.id);
              Navigator.pop(context);
            },
            child: const Text(
              'SÍ, ELIMINAR',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '⚙️ Ajustes y Configuración',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.cyan,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text(
          'NUEVO SABOR',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _abrirModalEditar(context, null),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF1E293B),
            child: SwitchListTile(
              secondary: const Icon(
                Icons.account_balance_wallet,
                color: Colors.cyanAccent,
              ),
              title: const Text('Mostrar Billetera en la barra inferior'),
              subtitle: const Text(
                'Al ocultarla se conservan sus gastos y saldo.',
              ),
              value: mostrarBilletera,
              onChanged: onCambiarMostrarBilletera,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '🛵 Ajustes de Domicilio:',
            style: TextStyle(
              color: Colors.cyan,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: TextEditingController(
                      text: costoEnvioDefault.toStringAsFixed(0),
                    ),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Costo de Envío Estándar (\$ MXN)',
                      prefixText: '\$',
                    ),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null) onCambiarCostoEnvio(parsed);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: telefonoRepartidor,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono Repartidor (WhatsApp)',
                      hintText: 'Ej. 524681234567',
                    ),
                    onChanged: onCambiarTelefonoRepartidor,
                  ),
                ],
              ),
            ),
          ),
          Card(
            color: const Color(0xFF1E293B),
            child: ListTile(
              leading: const Icon(
                Icons.message_outlined,
                color: Colors.cyanAccent,
              ),
              title: const Text('Mensajes de WhatsApp'),
              subtitle: const Text(
                'Edita confirmación, faltantes, repartidor y aviso en camino.',
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditorPlantillasMensajesVista(
                    plantillas: plantillasMensajes,
                    onGuardar: onGuardarPlantillas,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '💾 Respaldos y Seguridad:',
            style: TextStyle(
              color: Colors.cyan,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Exporta todos tus datos (ventas, gastos, sabores) a un archivo JSON o restáuralos cuando lo necesites.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: onExportar,
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text(
                            'EXPORTAR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amberAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: onImportar,
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text(
                            'IMPORTAR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '🔤 Tamaños de Letra (6 Niveles):',
            style: TextStyle(
              color: Colors.cyan,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Botones del Mostrador: Nivel ${nivelTextoMostrador.toInt()}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Slider(
                    value: nivelTextoMostrador,
                    min: 1,
                    max: 6,
                    divisions: 5,
                    activeColor: Colors.cyan,
                    onChanged: onCambiarNivelMostrador,
                  ),
                  Text(
                    'Total e Indicadores: Nivel ${nivelTextoTotal.toInt()}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Slider(
                    value: nivelTextoTotal,
                    min: 1,
                    max: 6,
                    divisions: 5,
                    activeColor: Colors.cyan,
                    onChanged: onCambiarNivelTotal,
                  ),
                  Text(
                    'Historial y Registro: Nivel ${nivelTextoHistorial.toInt()}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Slider(
                    value: nivelTextoHistorial,
                    min: 1,
                    max: 6,
                    divisions: 5,
                    activeColor: Colors.cyan,
                    onChanged: onCambiarNivelHistorial,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '🍿 Catálogo de Sabores y Costos:',
            style: TextStyle(
              color: Colors.cyan,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...menuSabores.map((sabor) {
            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: sabor.color,
                  child: Text(
                    sabor.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                title: Text(
                  sabor.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Venta: M \$${sabor.precioMediano.toStringAsFixed(0)} | G \$${sabor.precioGrande.toStringAsFixed(0)}\nOlla (1.0): \$${sabor.costoLoteCompleto.toStringAsFixed(0)} | Insumo: M \$${sabor.costoInsumosMediano} | G \$${sabor.costoInsumosGrande}\nDías: ${sabor.diasVenta.map(Fechas.nombreDiaSemana).join(', ')}',
                    style: const TextStyle(color: Colors.cyan, fontSize: 12),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.amberAccent),
                      onPressed: () => _abrirModalEditar(context, sabor),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _confirmarEliminacion(context, sabor),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class EditorPlantillasMensajesVista extends StatefulWidget {
  final Map<String, String> plantillas;
  final ValueChanged<Map<String, String>> onGuardar;
  const EditorPlantillasMensajesVista({
    super.key,
    required this.plantillas,
    required this.onGuardar,
  });
  @override
  State<EditorPlantillasMensajesVista> createState() =>
      _EditorPlantillasMensajesVistaState();
}

class _EditorPlantillasMensajesVistaState
    extends State<EditorPlantillasMensajesVista> {
  late final Map<String, TextEditingController> controles;
  static const titulos = {
    'confirmacion': 'Confirmación al cliente',
    'faltantes': 'Aviso de productos faltantes',
    'repartidor': 'Pedido para el repartidor',
    'enCamino': 'Aviso de pedido en camino',
  };

  @override
  void initState() {
    super.initState();
    controles = {
      for (final entry in plantillasDomicilioPredeterminadas.entries)
        entry.key: TextEditingController(
          text: widget.plantillas[entry.key] ?? entry.value,
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in controles.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    widget.onGuardar({
      for (final entry in controles.entries) entry.key: entry.value.text,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mensajes de WhatsApp'),
      backgroundColor: const Color(0xFF1E293B),
      actions: [
        TextButton.icon(
          onPressed: _guardar,
          icon: const Icon(Icons.save),
          label: const Text('GUARDAR'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Edita el texto que se prepara para cada etapa. Los marcadores entre llaves se reemplazan con los datos del pedido.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        const Text(
          'Marcadores: {{nombre}}, {{telefono}}, {{direccion}}, {{referencias}}, {{nota}}, {{pedido}}, {{faltantes}}, {{total}}, {{maps}}',
          style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...controles.entries.map(
          (entry) => Card(
            color: const Color(0xFF1E293B),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulos[entry.key] ?? entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: entry.value,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Escribe aquí el mensaje',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 70),
      ],
    ),
  );
}

class _DialogoEditarSabor extends StatefulWidget {
  final SaborInfo? sabor;
  final List<Color> paletaColores;
  final Function(SaborInfo) onGuardar;

  const _DialogoEditarSabor({
    required this.sabor,
    required this.paletaColores,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarSabor> createState() => _DialogoEditarSaborState();
}

class _DialogoEditarSaborState extends State<_DialogoEditarSabor> {
  late TextEditingController nombreCtrl;
  late TextEditingController emojiCtrl;
  late TextEditingController pMedianoCtrl;
  late TextEditingController pGrandeCtrl;
  late TextEditingController costoLoteCtrl;
  late TextEditingController cInsumoMedCtrl;
  late TextEditingController cInsumoGdeCtrl;
  late Color colorSeleccionado;

  late bool llevaQuesos;
  late bool llevaLimon;
  late bool llevaHuesito;
  late List<int> diasVenta;

  @override
  void initState() {
    super.initState();
    nombreCtrl = TextEditingController(text: widget.sabor?.nombre ?? '');
    emojiCtrl = TextEditingController(text: widget.sabor?.emoji ?? '🌽');
    pMedianoCtrl = TextEditingController(
      text: widget.sabor?.precioMediano.toStringAsFixed(0) ?? '50',
    );
    pGrandeCtrl = TextEditingController(
      text: widget.sabor?.precioGrande.toStringAsFixed(0) ?? '70',
    );
    costoLoteCtrl = TextEditingController(
      text: widget.sabor?.costoLoteCompleto.toStringAsFixed(0) ?? '350',
    );
    cInsumoMedCtrl = TextEditingController(
      text: widget.sabor?.costoInsumosMediano.toStringAsFixed(1) ?? '6.0',
    );
    cInsumoGdeCtrl = TextEditingController(
      text: widget.sabor?.costoInsumosGrande.toStringAsFixed(1) ?? '9.0',
    );
    colorSeleccionado = widget.sabor?.color ?? widget.paletaColores.first;

    llevaQuesos = widget.sabor?.llevaQuesos ?? false;
    llevaLimon = widget.sabor?.llevaLimon ?? true;
    llevaHuesito = widget.sabor?.llevaHuesito ?? false;
    final n = (widget.sabor?.nombre ?? '').toLowerCase();
    diasVenta = List<int>.from(
      widget.sabor?.diasVenta ??
          (n.contains('tuétano') || n.contains('tuetano')
              ? const [5, 6, 7]
              : const [1, 2, 3, 4, 5, 6, 7]),
    );
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    emojiCtrl.dispose();
    pMedianoCtrl.dispose();
    pGrandeCtrl.dispose();
    costoLoteCtrl.dispose();
    cInsumoMedCtrl.dispose();
    cInsumoGdeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(
        widget.sabor == null ? 'Nuevo Sabor' : 'Editar ${widget.sabor!.nombre}',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre Sabor',
                labelStyle: TextStyle(color: Colors.cyan),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: emojiCtrl,
              decoration: const InputDecoration(
                labelText: 'Emoji (un solo emoji)',
                labelStyle: TextStyle(color: Colors.cyan),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pMedianoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'P.Venta Med (\$)',
                      labelStyle: TextStyle(color: Colors.greenAccent),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: pGrandeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'P.Venta Gde (\$)',
                      labelStyle: TextStyle(color: Colors.greenAccent),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: costoLoteCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Costo Producción Olla 1.0 (\$ MXN)',
                labelStyle: TextStyle(color: Colors.amberAccent),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Días en que vendes este sabor:',
              style: TextStyle(color: Colors.cyanAccent),
            ),
            Wrap(
              spacing: 4,
              children:
                  const [
                        (1, 'Lun'),
                        (2, 'Mar'),
                        (3, 'Mié'),
                        (4, 'Jue'),
                        (5, 'Vie'),
                        (6, 'Sáb'),
                        (7, 'Dom'),
                      ]
                      .map(
                        (dia) => FilterChip(
                          label: Text(dia.$2),
                          selected: diasVenta.contains(dia.$1),
                          onSelected: (seleccionado) => setState(() {
                            if (seleccionado) {
                              if (!diasVenta.contains(dia.$1))
                                diasVenta.add(dia.$1);
                            } else {
                              diasVenta.remove(dia.$1);
                            }
                            diasVenta.sort();
                          }),
                        ),
                      )
                      .toList(),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: cInsumoMedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Costo Insumo/Vaso Med (\$)',
                      labelStyle: TextStyle(color: Colors.amberAccent),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: cInsumoGdeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Costo Insumo/Vaso Gde (\$)',
                      labelStyle: TextStyle(color: Colors.amberAccent),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Opciones Extra para Pedidos:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Lleva Quesos',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              value: llevaQuesos,
              onChanged: (v) => setState(() => llevaQuesos = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Lleva Limón y Chile',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              value: llevaLimon,
              onChanged: (v) => setState(() => llevaLimon = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Lleva Huesito de Espinazo',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              value: llevaHuesito,
              onChanged: (v) => setState(() => llevaHuesito = v ?? false),
            ),
            const SizedBox(height: 16),
            const Text(
              'Color de Fondo en Mostrador:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: widget.paletaColores.map((c) {
                bool sel = colorSeleccionado == c;
                return InkWell(
                  onTap: () => setState(() => colorSeleccionado = c),
                  child: CircleAvatar(
                    backgroundColor: c,
                    radius: 16,
                    child: sel
                        ? const Icon(Icons.check, color: Colors.black)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyan,
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            widget.onGuardar(
              SaborInfo(
                id:
                    widget.sabor?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                nombre: nombreCtrl.text,
                emoji: emojiCtrl.text,
                color: colorSeleccionado,
                precioMediano: double.tryParse(pMedianoCtrl.text) ?? 50.0,
                precioGrande: double.tryParse(pGrandeCtrl.text) ?? 70.0,
                costoLoteCompleto: double.tryParse(costoLoteCtrl.text) ?? 0.0,
                costoInsumosMediano:
                    double.tryParse(cInsumoMedCtrl.text) ?? 0.0,
                costoInsumosGrande: double.tryParse(cInsumoGdeCtrl.text) ?? 0.0,
                llevaQuesos: llevaQuesos,
                llevaLimon: llevaLimon,
                llevaHuesito: llevaHuesito,
                diasVenta: diasVenta,
              ),
            );
            Navigator.pop(context);
          },
          child: const Text(
            'GUARDAR SABOR',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// BOTÓN POP
// -----------------------------------------------------------------------------
class _BotonPop extends StatefulWidget {
  final String label;
  final double precio;
  final Color color;
  final double fontSizeLabel;
  final double fontSizePrecio;
  final VoidCallback onTap;

  const _BotonPop({
    required this.label,
    required this.precio,
    required this.color,
    required this.fontSizeLabel,
    required this.fontSizePrecio,
    required this.onTap,
  });

  @override
  State<_BotonPop> createState() => _BotonPopState();
}

class _BotonPopState extends State<_BotonPop> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.92),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _scale < 1 ? 0.55 : 0.22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.fontSizeLabel,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${widget.precio.toStringAsFixed(0)}',
                style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.fontSizePrecio,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
