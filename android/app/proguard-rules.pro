# Release builds are shrunk by R8; keep classes these plugins load by reflection.

# Incoming-call UI (serialised call params).
-keep class com.hiennv.flutter_callkit_incoming.** { *; }

# WebRTC native bindings.
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Local notifications (Gson-serialised notification details).
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
