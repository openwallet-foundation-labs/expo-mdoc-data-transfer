plugins {
  alias(libs.plugins.kotlin.multiplatform)
  alias(libs.plugins.android.kotlin.multiplatform.library)
  alias(libs.plugins.kotlin.cocoapods)
}

kotlin {
    jvmToolchain(17)

    android {
        namespace = "id.animo.mdoc.proximity"
        compileSdk = libs.versions.android.compileSdk.get().toInt()
        minSdk = libs.versions.android.minSdk.get().toInt()
    }

    listOf(iosX64(), iosArm64(), iosSimulatorArm64()).forEach {
        it.binaries.framework {
            baseName = "MdocProximity"
            isStatic = true
        }
    }

    cocoapods {
        version = "1.0"
        framework {
            baseName = "MdocProximity"
            isStatic = true
        }
    }
}
