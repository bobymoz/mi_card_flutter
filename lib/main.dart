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
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
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
  // --- Variáveis de Estado ---
  late OpenVPN engine;
  VPNStage? _vpnStage;
  VpnStatus? _vpnStatus;
  String? _deviceId;
  String _uiStatusText = "DESCONECTADO";
  Timer? _heartbeatTimer;
  bool _isLoading = false;
  
  // --- Sistema de Logs ---
  final List<String> _logs = []; // Lista para guardar os logs
  final ScrollController _logScrollCtrl = ScrollController();

  final String _apiBaseUrl = "http://51.79.117.132:8080";
  final String _whatsAppLink = "https://wa.me/258863018405";

  // CONFIGURAÇÃO BASE64 (A mesma que você forneceu)
  final String _vpnConfigBase64 = 
      "Y2xpZW50CmRldiB0dW4KcHJvdG8gdWRwCnJlbW90ZSA1MS43OS4xMTcuMTMyIDUzCnJlc29sdi1yZXRyeSBpbmZpbml0ZQpub2JpbmQKcGVyc2lzdC1rZXkKcGVyc2lzdC10dW4KcmVtb3RlLWNlcnQtdGxzIHNlcnZlcgphdXRoIFNIQTUxMgppZ25vcmUtdW5rbm93bi1vcHRpb24gYmxvY2stb3V0c2lkZS1kbnMKdmVyYiAzCjxjZXJ0PgotLS0tLUJFR0lOIENFUlRJRklDQVRFLS0tLS0KTUlJRFZEQ0NBanlnQXdJQkFnSVFjNDhYbURMaEZCVjRTSFE4NjIySVl6QU5CZ2txaGtpRzl3MEJBUXNGQURBVwpNUlF3RWdZRFZRUUREQXRGWVhONS1XSlRRU0JEUVRBZUZ3MHlOakF5TURjeU1UUTBNRGxhRncwek5qQXlNRFV5Ck1UUTBNRGxhTUJFeER6QU5CZ05WQkFNTUJtTnNhV1Z1ZENDQVNJd0RRWUpLb1pJaHZjTkFRRUJCUUFEZ2dFUAZENDNDQVFvQ2dnRUJBS3pHSzAveStZS2pOWW5yZFB1Y1VaRDhwcFgzcTJrd1ZLeUxoS2JObXhGaWE4YnlWSVJvClQwci9XNmgrTktaREs1UjBaM0xpeVd2NXlaZkhENlhvNC91U1Q1UTJRbW1TZG5yK0tIRnhOcnFibDVCRjRId1oKVGZIRWhyOHR5OXBhdko3bVhYSWRRd3p1R2x6am9ONWpBb2IrWXVNVGpKeU1qYktTaXZReWUrSG15eVhYMGpDeQpncWpnb2VwdTRwQThpR0cvVjRRdXhsWHh4OTJFd1M0LzdwRlpVUk9iNXp3b3E1NnpXVXFrVzJRS0VISlpVazdhCkdaUzRYQmtGT3Z6STV4VW85WUI4SEpQeUFLU1ptdnVjTU8yTmt4ZURIUzdva2FZOFd0Qkd0U1RremFtWjhNTWwKSThIMSswSmZ3MTJEN0cwOW55VGZlL0pCTWh3WTRIOUxsbFVDQXdFQUFhT0JvakNCbnpBSkJnTlZIUk1FQWpBQQpNQjBHQTFVZERnUVdCQlFrbWJHbWFmV0JpSFRzTlBKUko0UWlUUmp5TXpCUkJnTlZIU01FU2pCSWdCU0xyTDlFCkRyRzl6SUpFdmRrOVpDaDVxYUpwSnFFYXBCZ3dGakVVTUJJR0ExVUVBd3dMUldGemVTMVNVMUVHUVVGQ2ZcCkFSUVNiSVpxM29CMVVwenFJR2gxVWwrTUJNR0ExVWRKUVFNTUFvR0NDc0dBUVVGQndNQ01Bc0dBMVVkRHdRRQpBd0lIZ0RBTkJna3Foa2lHOXcwQkFRc0ZBQU9DQVFFQVo1d255Rlgwd1liOCtkeVd2VGNBclFQR25TelV6a0R0CnhRUVdrU3JwT1BlTlpPNEozZFR0dUppUGE5NEUvNkFteFl3SkRUVS9HUG5keHJUdWw3MXNKS0YvdzM1dENrMGEKU1dIM1NlK2owaVFSOW93bEFaTjV1ZDNDNkVSNWQzeXhhQnVqS2tsUUJwc25Ma2FML2VicmU5TGs2VmxmQmRPQwpYZXFGOFJuSTk2eE5HVDFFZzN5UHdnd3p2MzFHT3V1KzBnSUVOMXU0a2lYLzdodElsQWpFZldLZVpyRWw4OTlKCkRmVzBYRk1KOTlYRS9tTXZmS01OeVpoTXVXNk41M0U3WStmRG9PeWhSSXFLZ2JBQlErQWMzdWxsd29pMXVnVDYKUmd3bFlqM2NIRXlIM2ZSK29SdExQNmx2UGJWaFMwL0VmUWdqUXMxWFhpeC9lL09IamVxMTRRPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo8L2NlcnQ+CjxrZXk+Ci0tLS0tQkVHSU4gUFJJVkFURSBLRVktLS0tLQpNSUlFdkFJQkFEQU5CZ2txaGtpRzl3MEJBUUVGQUFTQ0JLWXdHZ1NpQWdFQUFvSUJBUUNzeEdLMC95K1lLak5ZCm5yZFB1Y1VaRDhwcFgzcTJrd1ZLeUxoS2JObXhGaWE4YnlWSVJvVDByL1c2aCtOS1pESzVSMFozTGl5V3Y1eVoKZkhENlhvNC91U1Q1UTJRbW1TZG5yK0tIRnhOcnFibDVCRjRId1pUZkhFaHI4dHk5cGF2SjdtWFhJZFF3enVHbAp6am9ONWpBb2IrWXVNVGpKeU1qYktTaXZReWUrSG15eVhYMGpDeWdxamdvZXB1NHBBOGlHRy9WNFF1eGxYeHg5CjJFd1M0LzdwRlpVUk9iNXp3b3E1NnpXVXFrVzJRS0VISlpVazdhR1pTNHhCa0ZPdnpJNXhVbzlZQjhISlB5QUsKU1ptdnVjTU8yTmt4ZURIUzdva2FZOFd0Qkd0U1RremFtWjhNTWxJOEgxKzBKZncxMkQ3RzA5bnlUZmUvSkJNCmh3WTRIOUxsbFVDQXdFQUFRSUNnZ0VBREduWmdtdUtzcGlDekorbUNHVERubW8yWFdUdmtscFZFVHdOWDVraApVTW82R1VEcUpDeWl6UjBZaXQzQ3RlM0RkTTQ0Vy8wVllTVFVJVXpMR1oyTkJrR1NVRTVYNnNsY0xMTjJHcktleQo0V0NvVDRSQWRyTE1rYWRAaHZrM2hkMzJaQ2NuK2I3eGhhUkxjdGEvajNQWDFiRzVLSlBMb0FtVm9rR3NYYllaCldoNnJTN2tHTS9waTRVbElZd1V2RGdQd1VTT2FXVkN6M3QxcUNSbzNDN1hQTDMxWUdaTFpBem1HWGx2cmtDZVAKb3VaSFlVY2R1NWFZQmRFZytDaG5SMFJ0UzVlK2JuZHJVWUR6M1ZDbTRZQ2dDVHZieXVQZUhrVTlxM0NFdjh3bgpQVXk4WlRHY1BzeFFkRktPTlJWZ3NBTW5KZnpQOHR6ZjNZS3VXY0d5dm1RNndLQmdRRHhmaElBdnEvQWpJajYKQ013MnE2eXpDRHMzZlg0WDQwcUxYcnE1Sk12dVpyRE9PSmJCRFQ2dkF0ckZjQXdxNUVVREdiRUVVenFjK0QxWApwajZPMmVlQWJ5d1pEeFZWR2xiTklnd25UK0RtSmp6UWJEdGZ4K0lvVytqSmpTbTRGRjlYcVZtWDNPcHJoeHdKCk83MXF5dVhjcG43aTZEZzI3QmY1K1hwdU9iYzhod0tCZ1FDM0owWTNWbkRMTzZ6aWNZT0N5Q2hjUGdnRjQ1ZHp0ClA4eXliWWhVdmViWkhSU00vS0dIbU8zMG1Od2p3UlNNY3FoTGk4T3c1TFcrNHZwQXBDdFNOVCtGT2RDY1lXWksKdTRWQmVzS3VKdTNBUFd3bDk5QTZ6Z0t4V3VOdVp6Ylh0RDJXajZ4QTF6S3Z0VHNmUlNIT3VkK0RBbWQvc09NUwpVVTNLWTdLcHBvSlF3S0JnRWRnOXh0SEdaV05OSE9MSkNsSXB2d29BN0RNSTNnVms1UVEvNW4zMlZzMitTMkxKCm13YmFScTdva1JYY1JGQWRYR01KM2xhekdsWEtuSjh6ZUxWWDRyajBVbjYzbGhRTjdYY1NYRlpOK1Z2Q2V5bEEKUXUzZmc1bDFERzJ5czBCSUlrOTlvaUMw2lvTjNtaVFRdFdNOFZJOTJDVmpkREl2cUlxWGhldU1uYStEQW9HQQpSc3dLcXFkZGhrRjNIN1Z3OW5xOHFVc1d6cWpzWWp5UjJ4VFlOamZKWkxsIjlUODArd1RNOERwRm4yTm1mckxvCk1QcE93b3Y5Y1luZW4xSEVtWmFWU2w4aVN3QzlMbWpKckIzdGJLWERGbUU3bnV3dHB4QmxvZDFscXdzVHQ2aXAKVGtmYStad1JLdVNCZG1BekV4bnpoWXhYTjN3RGY3ZE4zWndJSHk3VWpMSUNzQ2dZQitXS2t6bW5Fd2ovb2hrdApIU0dMUDdVZGROeTMwTVhzWXZHK1c4Z040YStTdXlxa1UwcDBDWWVERUtlRTUxeWZrdGxWdkxPeTI1YTJWUk4rCkRXNEpneDZJREtWQTNDVllIUkNTaEtPWStvWlB5Qk9IM28xNVFpM29taVZtSmJWdnc4STVqWTJEUjJDVStFanIKREQwNUU1NXQ4ak5pUTNLcHVOTEd2MC81emxwU1E9PQotLS0tLUVORCBQUklWQVRFIEtFWS0tLS0tCjwva2V5Pgo8Y2E+Ci0tLS0tQkVHSU4gQ0VSVElGSUNBVEUtLS0tLQpNSUlEU3pDQ0FqT2dBd0lCQWdJVVErRkFCUkJKc2htcmVnSFZTbk9vZ2FIVlNYNHdEUVlKS29aSWh2Y05BUUVMCkJRQXdGakVVTUJJR0ExVUVBd3dMUldGemVTMVNVMUVHUVVGQ2ZcCkFSUVNiSVpxM29CMVVwenFJR2gxVWwrTUExR0ExVUREd1FFQXdJQmdEQW5CZ2txaGtpRzl3MEJBUXNGQUFPQwpBUUVBU01yVnhSM084bk5XZTBCUitERDRGUDY1SDZWOAvRUlZTHZBNHgyRnBDL0E2CmNiY2N2QkJGQVRJU3NRZTBYTittalQ0bDZSdkxqVlA2MzM0TDZOGGxsVFdGNDl1YWtjZm94ak83ZXJyV011K00KZGNrMmoyOTFoMGU2TnBkUFJLVWZpTjk4NTUwbHJtcHowZHJoUjg1anZWYUVnR2M0cXd4MkpXM1VJOWxZRXBvOAppMGlHbEJ5ODk4RURwaGhsMHlFaGk0Y2dvY2FNVkcrQkxIUXZYYlVnaCtVTUFKdXZqdEs1RE1QdkYra0VXd0VvCnZoeWVJWTBiSzRkQUVKNU9wOENpTkNpYlpyTGt2YmVaZ1RvaHNweW10QTZURis4SXhCWDdFRE1jc1BDTkFxeWJGCm1welZwcURTd0szS2dOY2NIU2JiR1ZsaU0wUXkrOVNyMjkvTWNQeE5iUT09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0KPC9jYT4KPHRscy1jcnlwdD4KLS0tLS1CRUdJTiBPcGVuVlBOIFN0YXRpYyBrZXkgVjEtLS0tLQoxOWYwZTU5NDBiMDkwODJjMDI4NGMwMzY4NzhhMjRjNgpmODhjM2E0YjhmOWYzN2I5N2EzNWI4M2E3MGVjZWY0NwpmMWNhMDFhMDYzNTY3MmNhZThiMjk2NWRmZmFkYTBkYwo0NjM0NTI0MmEwZDVlNTg2NjE2MjQxMzU1MGNjMTg5NQo5M2M1Y2E2OWFhMGE5OGI3MzBjN2E4YzAyZWRmNWRmNApkZDI4ODEzZGI1YTgxYmU5ZjRmNjdmNzYwNjBjMDcyZgo5MjRjNWI5ZTJkYzcwYTU1MjdmMmEwZDcwZWY5YjIwMApkZDNhYjQ5NzNkMjJlNDYxZmU0NGMxZjcxOGVlMDY2Ngo2NDQ2OGYyOWRkYjcwMDdhNTkxMDI0MWRlYTYxNDA0NgozYWY0ZDZhYTY3NjQzYTEwODM2Yjc3YmFjODllY2Q1YwpiYjEyOThlNzA0YzA1ODc1Yzg0MmFjYTJkY2Y1YzZhYwpmYWNkMzU2MzU5OTZlYzIzODAwZjVkY2ZkZGYwNDczZgo4MjNmZGZkMDFmZGFmYmI5YTAxZTZlODFjNjdhZGFkMgo1OWIxMmZmZGU5YjBhNzA1M2UzODMyZGM0YTBmYTM0Mgo2ZDg5YTRhN2JhNzhjNjQ1YjQ4YjkzZDAwMGEwOGFkOAowNDY1NmMwOWFmYmY3N2UwZDYyYmZjMGVkZmE2YWEzMgotLS0tLUVORCBPcGVuVlBOIFN0YXRpYyBrZXkgVjEtLS0tLQo8L3Rscy1jcnlwdD4K";

  @override
  void initState() {
    super.initState();
    _addLog("App Iniciado.");
    _getDeviceId();
    _initOpenVPN();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _logScrollCtrl.dispose();
    super.dispose();
  }

  // --- FUNÇÃO DE LOGS (FILTRO DE SEGURANÇA) ---
  void _addLog(String log) {
    if (!mounted) return;

    // SEGURANÇA: Nunca mostrar chaves privadas ou certificados nos logs visuais
    if (log.contains("PRIVATE KEY") || 
        log.contains("CERTIFICATE") || 
        log.contains("tls-crypt") || 
        log.length > 500) {
      log = " [DADOS SENSÍVEIS OCULTADOS PELA SEGURANÇA] ";
    }

    setState(() {
      String hora = DateTime.now().toString().split(' ')[1].substring(0, 8);
      _logs.add("[$hora] $log");
    });
    
    // Auto-scroll para o final
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollCtrl.hasClients) {
        _logScrollCtrl.animateTo(
          _logScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        setState(() {
          _deviceId = androidInfo.id;
        });
        _addLog("Device ID obtido: ...${_deviceId?.substring(_deviceId!.length - 4)}");
      }
    } catch (e) {
      _addLog("Erro ao obter ID: $e");
    }
  }

  void _initOpenVPN() {
    _addLog("Inicializando Engine OpenVPN...");
    engine = OpenVPN(
      onVpnStageChanged: (stage, rawStage) {
        setState(() {
          _vpnStage = stage;
          _updateUIStatus(stage);
        });
        
        // Logar mudança de estágio
        _addLog("Estado VPN alterado para: ${stage?.name} ($rawStage)");

        if (stage == VPNStage.connected) {
          _addLog("CONEXÃO ESTABELECIDA COM SUCESSO!");
          _startHeartbeat();
        } else if (stage == VPNStage.disconnected) {
          _stopHeartbeat();
        } else if (stage == VPNStage.error) {
          _addLog("ERRO CRÍTICO NA VPN.");
        }
      },
      onVpnStatusChanged: (data) {
        setState(() => _vpnStatus = data);
      },
    );

    engine.initialize(
      groupIdentifier: "group.com.vpn.freemium",
      providerBundleIdentifier: "id.laskarmedia.openvpn_flutter.OpenVPNService",
      localizedDescription: "VPN Premium",
    );
  }

  void _updateUIStatus(VPNStage? stage) {
    if (stage == null) return;
    switch (stage) {
      case VPNStage.connected: _uiStatusText = "CONECTADO"; break;
      case VPNStage.connecting: _uiStatusText = "CONECTANDO..."; break;
      case VPNStage.disconnecting: _uiStatusText = "DESCONECTANDO..."; break;
      case VPNStage.disconnected: _uiStatusText = "DESCONECTADO"; break;
      default: _uiStatusText = "AGUARDANDO";
    }
  }

  Future<void> _handleConnectButton() async {
    if (_deviceId == null) {
      _showSnack("ID do dispositivo não encontrado.");
      return;
    }

    if (_vpnStage == VPNStage.connected || _vpnStage == VPNStage.connecting) {
      _addLog("Usuário solicitou desconexão.");
      engine.disconnect();
      return;
    }

    setState(() => _isLoading = true);
    _addLog(">>> INICIANDO PROCESSO DE CONEXÃO <<<");
    
    try {
      _addLog("1. Decodificando configuração segura...");
      String config = utf8.decode(base64Decode(_vpnConfigBase64));

      // AUMENTO DE TEMPO DE ESPERA (Injeta configuração extra)
      _addLog("2. Otimizando parâmetros de timeout (Wait More)...");
      config += "\nconnect-retry-max 5";
      config += "\nconnect-timeout 60"; // Espera até 60s
      config += "\nhand-window 120";    // Janela de handshake maior
      
      _addLog("3. Enviando configuração para o motor OpenVPN...");
      engine.connect(
        config,
        "VPN Premium",
        username: "",
        password: "",
        certIsRequired: false,
      );
      
    } catch (e) {
      _addLog("ERRO FATAL: $e");
      _showSnack("Erro interno.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _addLog("Iniciando Heartbeat (Validação a cada 5 min)...");
    
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (_vpnStage != VPNStage.connected) {
        timer.cancel();
        return;
      }

      try {
        _addLog("Enviando Heartbeat para API...");
        final url = Uri.parse('$_apiBaseUrl/api/heartbeat');
        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"device_id": _deviceId}),
        ).timeout(const Duration(seconds: 30)); // Timeout aumentado para 30s

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['action'] == 'disconnect') {
             _addLog("Servidor ordenou desconexão (Limite atingido).");
             engine.disconnect();
             _showDialog("Tempo Esgotado", "Limite diário expirou.");
          } else {
             _addLog("Heartbeat OK: Sessão válida.");
          }
        } else {
          _addLog("Erro Heartbeat API: ${response.statusCode}");
        }
      } catch (e) {
        _addLog("Falha Heartbeat (Rede): $e");
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  // --- TELA DE LOGS (MODAL) ---
  void _openLogsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[900],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("LOGS EM TEMPO REAL", style: TextStyle(color: Color(0xFF00FF41), fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white))
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _logScrollCtrl,
                padding: const EdgeInsets.all(10),
                itemCount: _logs.length,
                itemBuilder: (ctx, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _logs[index],
                    style: const TextStyle(
                      color: Colors.white70, 
                      fontFamily: 'Courier', 
                      fontSize: 12
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActivationDialog() {
    final TextEditingController codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Ativar Premium", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: codeCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Código",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("ENVIAR"),
            onPressed: () async {
              Navigator.pop(ctx);
              _addLog("Enviando código de ativação...");
              try {
                final response = await http.post(
                  Uri.parse('$_apiBaseUrl/api/activate'),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({"device_id": _deviceId, "code": codeCtrl.text}),
                ).timeout(const Duration(seconds: 30));
                
                if (response.statusCode == 200) {
                   _showSnack("Código enviado.");
                   _addLog("Código enviado com sucesso.");
                } else {
                   _addLog("Erro ao ativar: ${response.statusCode}");
                }
              } catch (e) {
                _addLog("Erro de conexão na ativação: $e");
              }
            },
          ),
        ],
      ),
    );
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
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    Color buttonColor = _vpnStage == VPNStage.connected ? const Color(0xFF00FF41) : 
                        (_vpnStage == VPNStage.connecting ? Colors.orange : Colors.red);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.terminal, color: Color(0xFF00FF41)), // Ícone de Logs
          onPressed: _openLogsModal,
          tooltip: "Ver Logs",
        ),
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
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0),
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
                  boxShadow: [BoxShadow(color: buttonColor.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)],
                ),
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Icon(Icons.power_settings_new, size: 70, color: buttonColor),
                ),
              ),
            ),
          ),
          // Botão pequeno de Logs abaixo do principal (Opcional, para facilitar)
          TextButton.icon(
             onPressed: _openLogsModal,
             icon: const Icon(Icons.info_outline, color: Colors.grey, size: 16),
             label: const Text("Ver Logs de Erro", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _launchWhatsApp,
                icon: const Icon(Icons.star, color: Colors.black),
                label: const Text("OBTER PREMIUM (20 MT)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
