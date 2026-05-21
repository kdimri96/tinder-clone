# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Razorpay
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
    public void onPayment*(...);
}

# Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Google Sign In
-keep class com.google.android.gms.** { *; }

# Socket.IO
-keep class io.socket.** { *; }
-keep class okhttp3.** { *; }
