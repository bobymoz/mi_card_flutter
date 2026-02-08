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
      title: 'VPN Premium',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00FF99),
        useMaterial3: true,
      ),
      home: const VPNHome(),
    );
  }
}

class VPNHome extends StatefulWidget {
  const VPNHome({Key? key}) : super(key: key);

  @override
  State<VPNHome> createState() => _VPNHomeState();
}

class _VPNHomeState extends State<VPNHome> with TickerProviderStateMixin {
  late OpenVPN engine;
  String _vpnStage = "disconnected";
  String _statusText = "DESCONECTADO";
  String? _deviceId;
  Timer? _heartbeatTimer;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final String _baseUrl = "http://51.79.117.132:8080";

  @override
  void initState() {
    super.initState();
    _getDeviceId();
    _initOpenVPN();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _deviceId = androidInfo.id;
      });
    }
  }

  void _initOpenVPN() {
    engine = OpenVPN(
      onVpnStatusChanged: (data) {
        setState(() {
          if (data?.vpnStatus != null) {
            String status = data!.vpnStatus!.name.toLowerCase();
            if (status == "connected") {
              _vpnStage = "connected";
              _statusText = "CONECTADO";
              _pulseController.stop();
              _startHeartbeat();
            } else if (status == "connecting" || status == "authenticating" || status == "reconnecting") {
              _vpnStage = "connecting";
              _statusText = "CONECTANDO...";
              _pulseController.repeat(reverse: true);
            } else {
              _vpnStage = "disconnected";
              _statusText = "DESCONECTADO";
              _pulseController.stop();
              _stopHeartbeat();
            }
          }
        });
      },
      onVpnStageChanged: (data, stage) {},
    );
    engine.initialize(
      groupIdentifier: "group.com.leone.vpn",
      providerBundleIdentifier: "id.laskarmedia.openvpn_flutter.OpenVPNService",
      localizedDescription: "VPN Premium",
    );
  }

  Future<void> _connectToVpn() async {
    if (_deviceId == null) return;

    setState(() {
      _vpnStage = "connecting";
      _pulseController.repeat(reverse: true);
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/connect'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"device_id": _deviceId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'allow') {
          String config = data['config'];
          engine.connect(config, "VPN Premium", username: "", password: "", certIsRequired: false);
        } else {
          _showAlert("Atenção", "Limite Diário Atingido.");
          _disconnectVPN();
        }
      } else {
        _showAlert("Erro", "Erro ao conectar na API.");
        _disconnectVPN();
      }
    } catch (e) {
      _showAlert("Erro", "Falha na conexão.");
      _disconnectVPN();
    }
  }

  void _disconnectVPN() {
    engine.disconnect();
    setState(() {
      _vpnStage = "disconnected";
      _statusText = "DESCONECTADO";
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      try {
        final response = await http.post(
             Uri.parse('$_baseUrl/api/heartbeat'),
             headers: {"Content-Type": "application/json"},
             body: jsonEncode({"device_id": _deviceId}),
        );
        if (response.statusCode == 200) {
           final data = jsonDecode(response.body);
           if (data['action'] == 'disconnect') {
             _disconnectVPN();
           }
        }
      } catch (e) {
        print("Heartbeat failed");
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  void _showAlert(String title, String msg) {
    if (!mounted) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("OK"))],
    ));
  }

  void _openWhatsApp() async {
    final Uri url = Uri.parse("https://wa.me/258863018405");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showAlert("Erro", "Não foi possível abrir o WhatsApp");
    }
  }

  void _showActivationDialog() {
    TextEditingController codeCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("Ativar Premium"),
      content: TextField(
        controller: codeCtrl,
        decoration: InputDecoration(hintText: "Código de Ativação"),
      ),
      actions: [
        TextButton(
          child: Text("ATIVAR"),
          onPressed: () async {
            Navigator.pop(ctx);
            try {
               await http.post(
                 Uri.parse('$_baseUrl/api/activate'),
                 body: jsonEncode({"code": codeCtrl.text, "device_id": _deviceId}),
                 headers: {"Content-Type": "application/json"}
               );
               _showAlert("Sucesso", "Código enviado.");
            } catch(e) {
               _showAlert("Erro", "Falha ao enviar.");
            }
          },
        )
      ],
    ));
  }

  Color _getButtonColor() {
    if (_vpnStage == 'connected') return Color(0xFF39FF14);
    if (_vpnStage == 'connecting') return Colors.red;
    return Colors.grey.shade800;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: _showActivationDialog,
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Spacer(),
          Text(_statusText, style: TextStyle(
            color: Colors.white, 
            fontSize: 20, 
            fontWeight: FontWeight.bold,
            letterSpacing: 2
          )),
          SizedBox(height: 50),
          Center(
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: () {
                  if (_vpnStage == 'disconnected') {
                    _connectToVpn();
                  } else {
                    _disconnectVPN();
                  }
                },
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getButtonColor(),
                    boxShadow: [
                      BoxShadow(
                        color: _getButtonColor().withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                    border: Border.all(color: Colors.white24, width: 4)
                  ),
                  child: Icon(
                    Icons.power_settings_new,
                    size: 70,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFD700),
                ),
                onPressed: _openWhatsApp,
                child: Text(
                  "OBTER PREMIUM ILIMITADO",
                  style: TextStyle(
                    color: Colors.black, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
