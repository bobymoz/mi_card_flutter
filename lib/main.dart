import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPN Freemium',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00FF41),
        useMaterial3: true,
      ),
      home: const VPNHomePage(),
    );
  }
}

class VPNHomePage extends StatefulWidget {
  const VPNHomePage({Key? key}) : super(key: key);

  @override
  State<VPNHomePage> createState() => _VPNHomePageState();
}

class _VPNHomePageState extends State<VPNHomePage> {
  late OpenVPN engine;
  VPNStage? _vpnStage; // Estágio atual da VPN
  VpnStatus? _vpnStatus; // Status de conexão
  String? _deviceId;
  String _uiStatusText = "DESCONECTADO";
  Timer? _heartbeatTimer;
  bool _isLoading = false;

  final String _apiBaseUrl = "http://51.79.117.132:8080";
  final String _whatsAppLink = "https://wa.me/258863018405";

  @override
  void initState() {
    super.initState();
    _getDeviceId();
    _initOpenVPN();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        setState(() {
          _deviceId = androidInfo.id;
        });
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        setState(() {
          _deviceId = iosInfo.identifierForVendor;
        });
      }
    } catch (e) {
      debugPrint("Erro DeviceID: $e");
    }
  }

  // --- CORREÇÃO AQUI ---
  void _initOpenVPN() {
    engine = OpenVPN(
      // A biblioteca retorna (VPNStage stage, String rawStage)
      // Corrigimos para usar o PRIMEIRO parâmetro (stage)
      onVpnStageChanged: (stage, rawStage) {
        setState(() {
          _vpnStage = stage;
          _updateUIStatus(stage);
        });
      },
      onVpnStatusChanged: (data) {
        setState(() {
          _vpnStatus = data;
        });
      },
    );

    engine.initialize(
      groupIdentifier: "group.com.vpn.freemium",
      providerBundleIdentifier: "id.laskarmedia.openvpn_flutter.OpenVPNService",
      localizedDescription: "VPN Conexão",
    );
  }

  void _updateUIStatus(VPNStage? stage) {
    if (stage == null) return;
    
    switch (stage) {
      case VPNStage.connected:
        _uiStatusText = "CONECTADO";
        _startHeartbeat();
        break;
      case VPNStage.connecting:
        _uiStatusText = "CONECTANDO...";
        break;
      case VPNStage.disconnecting:
        _uiStatusText = "DESCONECTANDO...";
        break;
      case VPNStage.disconnected:
        _uiStatusText = "DESCONECTADO";
        _stopHeartbeat();
        break;
      default:
        _uiStatusText = "AGUARDANDO";
    }
  }

  Future<void> _handleConnectButton() async {
    if (_deviceId == null) {
      _showSnack("ID do dispositivo não encontrado.");
      return;
    }

    if (_vpnStage == VPNStage.connected || _vpnStage == VPNStage.connecting) {
      engine.disconnect();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('$_apiBaseUrl/api/connect');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"device_id": _deviceId}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'];

        if (status == 'allow') {
          final config = data['config'];
          _connectToVPN(config);
        } else if (status == 'block') {
          _showDialog("Limite Atingido", "Limite diário de 2h atingido. Obtenha Premium!");
        } else {
          _showSnack("Status desconhecido.");
        }
      } else {
        _showSnack("Erro no servidor: ${response.statusCode}");
      }
    } catch (e) {
      _showSnack("Erro de conexão. Verifique sua internet.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _connectToVPN(String config) {
    engine.connect(
      config,
      "VPN Freemium",
      username: "",
      password: "",
      certIsRequired: false,
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (_vpnStage != VPNStage.connected) {
        timer.cancel();
        return;
      }
      try {
        final url = Uri.parse('$_apiBaseUrl/api/heartbeat');
        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"device_id": _deviceId}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['action'] == 'disconnect') {
             engine.disconnect();
             _showDialog("Tempo Esgotado", "Sessão gratuita finalizada.");
          }
        }
      } catch (e) {
        debugPrint("Heartbeat falhou");
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  void _showActivationDialog() {
    final TextEditingController _codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Ativar Premium", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _codeController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Código de Ativação",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("CANCELAR"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("ATIVAR"),
            onPressed: () async {
              Navigator.pop(context);
              await _activateCode(_codeController.text.trim());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _activateCode(String code) async {
    if (code.isEmpty) return;
    try {
      final url = Uri.parse('$_apiBaseUrl/api/activate');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"device_id": _deviceId, "code": code}),
      );
      
      if (response.statusCode == 200) {
         _showSnack("Código enviado para validação.");
      } else {
         _showSnack("Erro ao enviar código.");
      }
    } catch (e) {
      _showSnack("Erro de conexão.");
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showDialog(String title, String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    final Uri url = Uri.parse(_whatsAppLink);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showSnack("Erro ao abrir WhatsApp.");
    }
  }

  @override
  Widget build(BuildContext context) {
    Color buttonColor = Colors.grey.shade800;
    if (_vpnStage == VPNStage.connected) {
      buttonColor = const Color(0xFF00FF41);
    } else if (_vpnStage == VPNStage.connecting) {
      buttonColor = Colors.orange;
    } else if (_vpnStage == VPNStage.disconnecting) {
      buttonColor = Colors.redAccent;
    } else {
      buttonColor = Colors.red;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showActivationDialog,
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            _uiStatusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          if (_vpnStage == VPNStage.connected && _vpnStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "${_vpnStatus!.duration} • ${_vpnStatus!.byteIn}",
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          const SizedBox(height: 50),
          Center(
            child: GestureDetector(
              onTap: _handleConnectButton,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: buttonColor.withOpacity(0.1),
                  border: Border.all(color: buttonColor, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: buttonColor.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Icon(
                          Icons.power_settings_new,
                          size: 70,
                          color: buttonColor,
                        ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _launchWhatsApp,
                icon: const Icon(Icons.star, color: Colors.black),
                label: const Text(
                  "OBTER PREMIUM (20 MT)",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
