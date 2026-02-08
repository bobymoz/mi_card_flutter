# Manter o Flutter funcionando
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# MANTER O OPENVPN (Isso impede que a compressão quebre a VPN)
-keep class id.laskarmedia.openvpn_flutter.** { *; }
-keep class de.blinkt.openvpn.** { *; }
-dontwarn id.laskarmedia.openvpn_flutter.**
-dontwarn de.blinkt.openvpn.**

# Otimizações gerais
-dontwarn android.support.**
-keep class android.support.** { *; }
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
