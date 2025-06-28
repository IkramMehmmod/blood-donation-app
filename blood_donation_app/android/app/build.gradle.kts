plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // Required for Firebase
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.blood_donation_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.blood_donation_app"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        
        // Production configuration
        manifestPlaceholders["appName"] = "Blood Donation"
        manifestPlaceholders["appNameShort"] = "BloodBridge"
    }

    buildTypes {
        release {
            // TODO: Configure production signing
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            
            // Production optimizations
            isDebuggable = false
            isJniDebuggable = false
            isRenderscriptDebuggable = false
            isPseudoLocalesEnabled = false
            isZipAlignEnabled = true
        }
        
        debug {
            versionNameSuffix = "-debug"
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Java 8+ desugaring
    add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BoM
    add("implementation", platform("com.google.firebase:firebase-bom:32.7.3"))
    add("implementation", "com.google.firebase:firebase-messaging:23.4.0")

    // Google Play services base
    add("implementation", "com.google.android.gms:play-services-base:18.7.0")

    // MultiDex support
    add("implementation", "androidx.multidex:multidex:2.0.1")

    add("implementation", "androidx.work:work-runtime:2.8.1")


}
