# Prevent R8 from obfuscating or stripping your networking packets and models
-keep class com.tether.app.tether.** { *; }

# Protect Bouncy Castle cryptographic classes from being broken during minification
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Prevent stripping of standard reflection and JSON data structures
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
