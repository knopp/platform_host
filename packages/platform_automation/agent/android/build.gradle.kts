// UI Automator agent. The app itself is empty; the agent is its instrumentation
// test (src/androidTest), which drives any app on the device through
// UiAutomation. See src/androidTest/.../PAAgentServer.java.
plugins {
    id("com.android.application") version "9.3.1"
}

android {
    namespace = "dev.platformhost.automation"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.platformhost.automation"
        minSdk = 24
        targetSdk = 36
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
    androidTestImplementation("com.squareup.okhttp3:okhttp:4.12.0")
}
