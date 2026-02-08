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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPN Freemium',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00FF41), // Verde Cyberpunk
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF41),
          secondary: Color(0xFFFF003C), // Vermelho Cyberpunk
        ),
      ),
      home: const VPNHomePage(),
    );
  }
}

class VPNHomePage extends StatefulWidget {
  const VPNHomePage({super.key});

  @override
  State<VPNHomePage> createState() => _VPNHomePageState();
}

class _VPNHomePageState extends State<VPNHomePage> {
  // --- Variáveis de Estado ---
  late OpenVPN engine;
  VPNStage? _vpnStage; // Estágio atual da VPN (connected, disconnected, etc)
  VpnStatus? _vpnStatus; // Status detalhado (bytes, duração)
  String? _deviceId;
  String _uiStatusText = "DESCONECTADO";
  Timer? _heartbeatTimer;
  bool _isLoading = false;

  // --- Configurações da API ---
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

  // 1. Obter ID do Dispositivo
  Future<void> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        setState(() {
          // Usando 'id' como identificador único
          _deviceId = androidInfo.id;
        });
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        setState(() {
          _deviceId = iosInfo.identifierForVendor;
        });
      }
    } catch (e) {
      debugPrint("Erro ao obter Device ID: $e");
    }
  }

  // 2. Inicializar Engine OpenVPN (CORREÇÃO DO BUG AQUI)
  void _initOpenVPN() {
    engine = OpenVPN(
      // Callback para mudança de Estágio (Conectando, Conectado, Desconectado)
      onVpnStageChanged: (data, stage) {
        setState(() {
          _vpnStage = stage;
          _updateUIStatus(stage);
        });
      },
      // Callback para mudança de Status (Dados, Tempo) - Opcional para UI
      onVpnStatusChanged: (data) {
        setState(() {
          _vpnStatus = data;
        });
      },
    );

    engine.initialize(
      groupIdentifier: "group.com.vpn.freemium",
      providerBundleIdentifier: "id.laskarmedia.openvpn_flutter.OpenVPNService",
      localizedDescription: "VPN Conexão Segura",
    );
  }

  // Atualiza o texto da UI baseado no estágio
  void _updateUIStatus(VPNStage stage) {
    switch (stage) {
      case VPNStage.connected:
        _uiStatusText = "CONECTADO";
        _startHeartbeat(); // Inicia o timer quando conecta
        break;
      case VPNStage.connecting:
        _uiStatusText = "CONECTANDO...";
        break;
      case VPNStage.disconnecting:
        _uiStatusText = "DESCONECTANDO...";
        break;
      case VPNStage.disconnected:
        _uiStatusText = "DESCONECTADO";
        _stopHeartbeat(); // Para o timer quando desconecta
        break;
      default:
        _uiStatusText = "AGUARDANDO";
    }
  }

  // 3. Lógica do Botão Conectar
  Future<void> _handleConnectButton() async {
    if (_deviceId == null) {
      _showSnack("Erro: ID do dispositivo não encontrado.");
      return;
    }

    // Se já estiver conectado ou conectando, desconecta
    if (_vpnStage == VPNStage.connected || _vpnStage == VPNStage.connecting) {
      engine.disconnect();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Chamada à API
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
          // Sucesso: Conectar na VPN
          final config = data['config']; // String .ovpn
          _connectToVPN(config);
        } else if (status == 'block') {
          // Bloqueado
          _showDialog("Limite Atingido", "Você atingiu seu limite diário de 2 horas. Adquira o Premium!");
        } else {
          _showSnack("Resposta desconhecida do servidor.");
        }
      } else {
        _showSnack("Erro no servidor: ${response.statusCode}");
      }
    } catch (e) {
      _showSnack("Erro de conexão: Verifique sua internet.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _connectToVPN(String config) {
    engine.connect(
      config,
      "VPN Freemium",
      username: "", // Se sua VPN não usa user/pass, deixe vazio
      password: "",
      certIsRequired: false,
    );
  }

  // 4. Heartbeat (Ping a cada 5 min)
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
             // O servidor mandou desconectar (tempo acabou)
             engine.disconnect();
             _showDialog("Tempo Esgotado", "Sua sessão gratuita expirou.");
          }
        }
      } catch (e) {
        debugPrint("Falha no Heartbeat: $e");
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  // 5. Ativação de Código
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
            hintText: "Digite seu código",
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("CANCELAR"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("ATIVAR", style: TextStyle(color: Color(0xFF00FF41))),
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
         _showSnack("Código enviado! Se válido, seu acesso será liberado.");
      } else {
         _showSnack("Falha ao enviar código.");
      }
    } catch (e) {
      _showSnack("Erro de conexão.");
    }
  }

  // --- UI Helpers ---
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showDialog(String title, String msg) {
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
      _showSnack("Não foi possível abrir o WhatsApp.");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define a cor do botão baseado no estado
    Color buttonColor = Colors.grey;
    if (_vpnStage == VPNStage.connected) {
      buttonColor = const Color(0xFF00FF41); // Verde
    } else if (_vpnStage == VPNStage.connecting) {
      buttonColor = const Color(0xFFFFA500); // Laranja
    } else {
      buttonColor = const Color(0xFFFF003C); // Vermelho
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
          
          // Texto de Status
          Text(
            _uiStatusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          
          if (_vpnStage == VPNStage.connected && _vpnStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                "${_vpnStatus!.duration} • ${_vpnStatus!.byteIn}",
                style: const TextStyle(color: Colors.white70),
              ),
            ),

          const SizedBox(height: 50),

          // Botão Grande Central
          Center(
            child: GestureDetector(
              onTap: _handleConnectButton,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: buttonColor.withOpacity(0.1),
                  border: Border.all(color: buttonColor, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: buttonColor.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Icon(
                          Icons.power_settings_new,
                          size: 80,
                          color: buttonColor,
                        ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // Botão Premium (Rodapé)
          Padding(
            padding: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700), // Dourado
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _launchWhatsApp,
                icon: const Icon(Icons.star, color: Colors.black),
                label: const Text(
                  "OBTER PREMIUM (20 MT)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
