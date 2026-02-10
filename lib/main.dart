import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: const Color(0xFF00FF41),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

// --- TELA DE SPLASH (Início Bonito) ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const VPNHomePage()));
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield, size: 100, color: Color(0xFF00FF41)),
            const SizedBox(height: 20),
            const Text("VPN PREMIUM", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Color(0xFF00FF41))
          ],
        ),
      ),
    );
  }
}

// --- TELA PRINCIPAL ---
class VPNHomePage extends StatefulWidget {
  const VPNHomePage({Key? key}) : super(key: key);
  @override
  State<VPNHomePage> createState() => _VPNHomePageState();
}

class _VPNHomePageState extends State<VPNHomePage> with TickerProviderStateMixin {
  late OpenVPN engine;
  VPNStage? _vpnStage = VPNStage.disconnected;
  VpnStatus? _vpnStatus;
  String? _deviceId;
  String _uiStatusText = "DESCONECTADO";
  Timer? _heartbeatTimer;
  Timer? _connectionTimeoutTimer;
  
  // Animação
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Logs
  final List<String> _logs = [];
  final ScrollController _logScrollCtrl = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final String _apiBaseUrl = "http://51.79.117.132:8080";
  
  // CONFIGURAÇÃO RAW
  final String _vpnConfigRaw = '''
client
dev tun
proto udp
remote 51.79.117.132 53
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
ignore-unknown-option block-outside-dns
verb 3
<cert>
-----BEGIN CERTIFICATE-----
MIIDVDCCAjygAwIBAgIQc48XmDLhFBV4SHQ8622IYzANBgkqhkiG9w0BAQsFADAW
MRQwEgYDVQQDDAtFYXN5LVJTQSBDQTAeFw0yNjAyMDcyMTQ0MDlaFw0zNjAyMDUy
MTQ0MDlaMBExDzANBgNVBAMMBmNsaWVudDCCASIwDQYJKoZIhvcNAQEBBQADggEP
ADCCAQoCggEBAKzGK0/y+YKjNYnrdPucUZD8ppX3q2kwVKyLhKbNmxFia8byVIRo
T0r/W6h+NKZDK5R0Z3LiyWv5yZfHD6Xo4/uST5Q2QmmSdnr+KHFxNrqbl5BF4HwZ
TfHEhr8ty9pavJ7mXXIdQwzuGlzjoN5jAob+YuMTQjyMjbKSivQye+HmyYXX0jCy
gqjgoepu4pA8iGG/V1QuxlXxx92EwS4/7pFZUROb5zwoq56zWUqkW2QKEHJZOk7a
GZS4XBkFOvzI5xUo9YB8HJPyAKSZmvucMO2NkxeDHS7okaY8WtBGtSTkzamZ8MMl
I8H1+0Jfw12D7G09nyTfe/JBMhwY4H9LllUCAwEAAaOBojCBnzAJBgNVHRMEAjAA
MB0GA1UdDgQWBBQkmbGmafWBiHTsNPJRJ4QiTRjyMzBRBgNVHSMESjBIgBSLrL9E
DrG9zIJEvdk9ZCh5qaJpJqEapBgwFjEUMBIGA1UEAwwLRWFzeS1SU0EgQ0GCFEPh
QARQSbIZq3oB1UpzqIGh1Ul+MBMGA1UdJQQMMAoGCCsGAQUFBwMCMAsGA1UdDwQE
AwIHgDANBgkqhkiG9w0BAQsFAAOCAQEAZ5wnyFX0wYb8+dyWvTcArQPGnSzUzkDt
xQQWkSrpOPeNZO4J3dTtuJfPa94E/6BmxYwJDTU/GPndxrTul71sJKF/w35tCk0a
SWH3Se+j0iQR9owlAZN5ud3C6ER5d3yxaBujKklQBpsnLkaL/ebre9Lk6VlmBdOC
XeqF8RnI96xNGT1Eg3yPwgwzv31GOuu+0gIEN1u4kiX/7htIlAjEfWKQZrEl899J
DfW0XFMJ99XE/mMvfKMNyZhMuW6N53E7Y+fDoOyhRIqKgbABQ+Ac3ullwoi1ugT6
RgwlYj3cHEyH3fR+oRtLP6lvPbVhS0/EfQgjQs1XXix/e/OHjeq14Q==
-----END CERTIFICATE-----
</cert>
<key>
-----BEGIN PRIVATE KEY-----
MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCsxitP8vmCozWJ
63T7nFGQ/KaV96tpMFSsi4SmzZsRYmvG8lSEaE9K/1uofjSmQyuUdGdy4slr+cmX
xw+l6OP7kk+UNkJpknZ6/ihxcTa6m5eQReB8GU3xxIa/LcvaWrye5l1yHUMM7hpc
46DeYwKG/mLjE0I8jI2ykor0Mnvh5smF19IwsoKo4KHqbuKQPIhhv1dULsZV8cfd
hMEuP+6RWVETm+c8KKues1lKpFtkChByWTpO2hmUuFwZBTr8yOcVKPWAfByT8gCk
mZr7nDDtjZMXgx0u6JGmPFrQRrUk5M2pmfDDJSPB9ftCX8Ndg+xtPZ8k33vyQTIc
GOB/S5ZVAgMBAAECggEADBnZzmuKspiCzJ+mCGTDnmo2XWTvklpVETwOX5khUMo6
GUDqJCyizR0Yit3Cte3DdM44W/wVYSTUIUzLGZ2NBkGSUE5X6slcLLN2GrKew4WC
oT4RAdrLMkadAhvk3hd32ZCcn+b7xhaRLcta/j3PX1bG5KJPLoAmVokGsXbYZWh6
cS7kGM/pi4UlIfwUvDgPwUSOaWVCz3t1qCRo3C7XPL31YGZLZAzmGXlvrkCePouZ
HYUcdu5agBdEg+ChnR0RtS5e+bndrUYDz3VCm4YCgCTvbyuPeHkU9q3CEv8wnPUy
8ZTGcPsxQdFKONRVgsAMnJfzP8tzf3YKuWcGyvmQ6wKBgQDxfhIAvq/AjIj6CMw2
q6yzCDs3fX4X40qLbrq5JMvuZrDOOJbBDT6vAtrFcAwq5EUDGbEEUzqc+D1Xpj6O
2eeAbywZDxVVGlbNIgwnT+DmJjzQbDtfx+IoW+jJjSm4FF9XqVmX3OprhxwJO71q
yuXcpn7i6Dg27Bf5+XpuObc8hwKBgQC3J0Y3VnDLO6zicYOCyChcPggF45dztP8y
ybYhUvebZHRSM/KGHmO30mNwjwRSMcqhLi8Ow5LW+4vpApCtSNT+FOdCcYWZKu4V
BesKuJu3APCwl99A6zgKxWuNuZzbXtD2Wj6xA1zKvtTsfRSHOud+DAmd/sOMSUU3
KY7KppoJQwKBgEdg9xtHQZWNNHOLJClIpvwoA7DMI/gVk5QQ/5n32Vs2+S2LJmwb
aRq7okRXcRFAdXGMJ3lazGlXKnJ8zeLVX4rj0Un63lhQN7XcSXFZN+VvCeylAQu3
fg5l1DG2ys0BIIk9oiC0CIoN3miQQtWM8VI92CVjdDIvqIqXheuMna+DAoGARswK
q1dhkF3H7Vw9nq8qUsWzqjsYjyR2xTYNjgIZLlr9T80+wTM8DpFn2NmfrPoMPpOw
ov9cYnen1HEmZaVSl8iSwC9LmjJrB3tbKLDFmE7nuwtpxBlod1lqwsTt6ipTkfa+
ZwRKuSBdA/ExnzhYxXN3wDf7dN3ZwIHy7UjLICsCgYB+WKkzmnEwj/ohktHSGLP7
UdDNy30MXsYvG+W8gN4a+SuyqkU0p0CYeDEKeE51yfktlVvLOy25a2VRN+DW4Jgx
6KDKVA3CVYHRCShKOY+oZPyBOH3o15Qi3omiVmJbVvw8I5jY2DR2CU+EjrDDO5EZ
5t8jNiQ3KpunLGv0/5zlpQ==
-----END PRIVATE KEY-----
</key>
<ca>
-----BEGIN CERTIFICATE-----
MIIDSzCCAjOgAwIBAgIUQ+FABFBJshmregHVSnOogaHVSX4wDQYJKoZIhvcNAQEL
BQAwFjEUMBIGA1UEAwwLRWFzeS1SU0EgQ0EwHhcNMjYwMjA3MjE0NDA5WhcNMzYw
MjA1MjE0NDA5WjAWMRQwEgYDVQQDDAtFYXN5LVJTQSBDQTCCASIwDQYJKoZIhvcN
AQEBBQADggEPADCCAQoCggEBAJ1kzQMuRiVNAHkG2mbn/Ak3qc2ZdosEfJ1m5/nl
A3c2EnumFmtMJAKnhT3IzKC6A6CvnRPMkG5Xmb8+QvJst4AIz0Hrub7Sf24hBh42
98zfVwejrZKfUgp4TL26/amvJ8yG6tUs74rvFb62Q7loJpjjvbnABUUkjnjmCYhZ
rs9GUXOFvmFK6O8/00F16a5C1S4Jn7TsuxjGuPinZn2THfzZC0RnYlfMm4IJG3yC
DiLPAmoTJRm40LjoLg60qjUsWq/wmI5pCg2aX37pbUaT8XNDz/kTntAfi8w7q6/b
6DVqAwRgIsLiAQRzW+7k1vdkk2AvA/UurUmt/hpdwI8Dp10CAwEAAaOBkDCBjTAM
BgNVHRMEBTADAQH/MB0GA1UdDgQWBBSLrL9EDrG9zIJEvdk9ZCh5qaJpJjBRBgNV
HSMESjBIgBSLrL9EDrG9zIJEvdk9ZCh5qaJpJqEapBgwFjEUMBIGA1UEAwwLRWFz
eS1SU0EgQ0GCFEPhQARQSbIZq3oB1UpzqIGh1Ul+MAsGA1UdDwQEAwIBBjANBgkq
hkiG9w0BAQsFAAOCAQEASMrVxR3O8nNWe0PR+DD4FP65H6V8/EIYLvA4x2FpC/A6
cbccvBBFATISsQe0XN+ZTY4l6RvLjVP6334L6N8llTWG49uakcfoxjO7errWMu+M
dck2j291h0e6NpdPRKUfiN98550lrmpz0drhR85jvVaEgGc4qwx2JW3UI9lYEpo8
i2GlBy898EDphhl0yEhi4cgocaMVG+BLHQvXbUgh+UMAJuvjtK5DMPvF+kEWwEoo
vhyeOY0bK4dAEJ5Op8CiNCibZrLkvbeZmehspymtA6TF+8IxBX7EDMcsPCNAqybF
mpzZpqDSwK3KgNccHSbbGVliM0Qy+9Sr29/McPxNbQ==
-----END CERTIFICATE-----
</ca>
<tls-crypt>
-----BEGIN OpenVPN Static key V1-----
19f0e5940b09082c0284c036878a24c6
f88c3a4b8f9f37b97a35b83a70ecef47
f1ca01a0635672cae8b2965dffada0dc
46345242a0d5e5866162413550cc1895
93c5ca69aa0a98b730c7a8c02edf5df4
dd28813db5a81be9f4f67f76060c072f
924c5b9e2dc70a5527f2a0d70ef9b200
dd3ab4973d22e461fe44c1f718ee0666
64468f29ddb7007a5910241dea614046
3af4d6aa67643a10836b77bac89ecd5c
bb1298e704c05875c842aca2dcf5c6ac
facd35635996ec23800f5dcfddf0473f
823fdfd01fdafbb9a01e6e81c67adad2
59b12ffde9b0a7053e3832dc4a0fa342
6d89a4a7ba78c645b48b93d000a08ad8
04656c09afbf77e0d62bfc0edfa6aa32
-----END OpenVPN Static key V1-----
</tls-crypt>
''';

  @override
  void initState() {
    super.initState();
    _addLog("App Iniciado. Versão Release.");
    _getDeviceId();
    _initOpenVPN();
    
    // Configura animação de pulso
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    _logScrollCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // --- LOGS E UTILITÁRIOS ---
  void _addLog(String log) {
    if (!mounted) return;
    if (log.length > 500) log = "${log.substring(0, 500)}...";
    setState(() {
      String hora = DateTime.now().toString().split(' ')[1].substring(0, 8);
      _logs.add("[$hora] $log");
    });
    // Auto-scroll só se o drawer estiver aberto
    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollCtrl.hasClients) _logScrollCtrl.jumpTo(_logScrollCtrl.position.maxScrollExtent);
      });
    }
  }

  Future<void> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      setState(() => _deviceId = androidInfo.id);
      _addLog("ID Carregado: ...${_deviceId?.substring(_deviceId!.length - 4)}");
    }
  }

  void _initOpenVPN() {
    engine = OpenVPN(
      onVpnStageChanged: (stage, rawStage) {
        if (stage == _vpnStage) return; // Evita duplicidade

        setState(() {
          _vpnStage = stage;
          _updateUIStatus(stage);
        });
        
        _addLog("Status: ${stage?.name}");

        if (stage == VPNStage.connected) {
          _addLog("CONEXÃO SUCESSO!");
          _pulseController.stop();
          _connectionTimeoutTimer?.cancel(); // Cancela timeout
          _startHeartbeat();
        } else if (stage == VPNStage.disconnected) {
          _stopHeartbeat();
          _pulseController.stop();
        } else if (stage == VPNStage.connecting) {
          _pulseController.repeat(reverse: true);
        }
      },
      onVpnStatusChanged: (data) => setState(() => _vpnStatus = data),
    );

    engine.initialize(
      groupIdentifier: "group.com.vpn.premium",
      providerBundleIdentifier: "id.laskarmedia.openvpn_flutter.OpenVPNService",
      localizedDescription: "VPN Premium",
    );
  }

  void _updateUIStatus(VPNStage? stage) {
    switch (stage) {
      case VPNStage.connected: _uiStatusText = "CONECTADO"; break;
      case VPNStage.connecting: _uiStatusText = "CONECTANDO..."; break;
      case VPNStage.disconnecting: _uiStatusText = "DESCONECTANDO..."; break;
      case VPNStage.disconnected: _uiStatusText = "DESCONECTADO"; break;
      default: _uiStatusText = "AGUARDANDO";
    }
  }

  // --- LÓGICA DE CONEXÃO ROBUSTA ---
  Future<void> _handleConnectButton() async {
    if (_deviceId == null) { _showSnack("ID não carregado."); return; }
    
    // Se estiver conectado ou conectando, desconecta
    if (_vpnStage == VPNStage.connected || _vpnStage == VPNStage.connecting) {
      engine.disconnect();
      return;
    }

    _addLog(">>> INICIANDO CONEXÃO <<<");
    
    // UI: Força estado 'Conectando' imediatamente
    setState(() {
      _vpnStage = VPNStage.connecting;
      _uiStatusText = "CONECTANDO...";
      _pulseController.repeat(reverse: true);
    });

    try {
      // Configuração
      String config = _vpnConfigRaw;
      config += "\nconnect-retry-max 5"; // Tenta 5 vezes
      config += "\nconnect-timeout 10"; // Timeout curto por tentativa
      
      _addLog("Enviando config para Engine...");
      engine.connect(config, "VPN Premium", username: "", password: "", certIsRequired: false);
      
      // TIMEOUT MANUAL DE 60 SEGUNDOS
      // Se o OpenVPN não responder nada em 60s, resetamos a UI
      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = Timer(const Duration(seconds: 60), () {
        if (_vpnStage == VPNStage.connecting) {
          _addLog("TIMEOUT: Servidor não respondeu em 60s.");
          engine.disconnect();
          _showSnack("Sem resposta do servidor. Tente novamente.");
        }
      });

    } catch (e) {
      _addLog("Erro Crítico: $e");
      engine.disconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      try {
        final response = await http.post(
          Uri.parse('$_apiBaseUrl/api/heartbeat'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"device_id": _deviceId}),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['action'] == 'disconnect') {
             engine.disconnect();
             _showDialog("Tempo Esgotado", "Limite diário expirou.");
          }
        }
      } catch (e) { _addLog("Heartbeat Falhou (Rede Instável)"); }
    });
  }

  void _stopHeartbeat() => _heartbeatTimer?.cancel();

  // --- UI AUXILIAR ---
  void _showSnack(String msg) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showDialog(String title, String msg) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: Text(msg),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]
    ));
  }

  @override
  Widget build(BuildContext context) {
    Color btnColor = _vpnStage == VPNStage.connected ? const Color(0xFF00FF41) : 
                     (_vpnStage == VPNStage.connecting ? Colors.amber : Colors.red);

    return Scaffold(
      key: _scaffoldKey,
      // --- DRAWER DE LOGS (LATERAL) ---
      endDrawer: Drawer(
        backgroundColor: const Color(0xFF111111),
        child: Column(
          children: [
            const SizedBox(height: 50),
            const Text("LOGS DO SISTEMA", style: TextStyle(color: Color(0xFF00FF41), fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(color: Colors.grey),
            Expanded(
              child: ListView.builder(
                controller: _logScrollCtrl,
                itemCount: _logs.length,
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(_logs[i], style: const TextStyle(color: Colors.white70, fontFamily: 'Courier', fontSize: 11)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text("COPIAR LOGS"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                onPressed: () {
                   Clipboard.setData(ClipboardData(text: _logs.join("\n")));
                   Navigator.pop(context);
                   _showSnack("Logs copiados!");
                },
              ),
            )
          ],
        ),
      ),
      
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: const Icon(Icons.shield, color: Color(0xFF00FF41)),
        title: const Text("VPN PREMIUM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          // Botão que abre os Logs
          TextButton(
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(), 
            child: const Text("LOGS", style: TextStyle(color: Colors.grey))
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {/* Logica de ativacao mantida */},
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Text(_uiStatusText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          
          if (_vpnStage == VPNStage.connected && _vpnStatus != null)
             Text("${_vpnStatus!.duration} • ${_vpnStatus!.byteIn}", style: const TextStyle(color: Colors.white70)),
          
          const SizedBox(height: 50),
          
          // BOTÃO PULSANTE
          Center(
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: _handleConnectButton,
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, 
                    color: btnColor.withOpacity(0.1), 
                    border: Border.all(color: btnColor, width: 4), 
                    boxShadow: [BoxShadow(color: btnColor.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)]
                  ),
                  child: const Center(child: Icon(Icons.power_settings_new, size: 70, color: Colors.white)),
                ),
              ),
            ),
          ),
          
          const Spacer(),
          
          // Rodapé
          Padding(
            padding: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
            child: SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async => await launchUrl(Uri.parse("https://wa.me/258863018405"), mode: LaunchMode.externalApplication), icon: const Icon(Icons.star, color: Colors.black), label: const Text("OBTER PREMIUM (20 MT)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
          ),
        ],
      ),
    );
  }
}
