# Keep Flutter shared_preferences Pigeon and JNI classes from being stripped or renamed by R8
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# Keep Kotlin Coroutine and Bridge types used in Pigeon / platform channel interop
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
