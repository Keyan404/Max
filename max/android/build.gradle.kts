allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            val android = extensions.getByName("android")
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                if (getNamespace.invoke(android) == null) {
                    setNamespace.invoke(android, project.group.toString())
                }
            } catch (e: Exception) {}

            try {
                val getCompileOptions = android.javaClass.getMethod("getCompileOptions")
                val compileOptions = getCompileOptions.invoke(android)
                val setSourceCompatibility = compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java)
                val setTargetCompatibility = compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java)
                setSourceCompatibility.invoke(compileOptions, JavaVersion.VERSION_17)
                setTargetCompatibility.invoke(compileOptions, JavaVersion.VERSION_17)
            } catch (e: Exception) {}

            try {
                val setCompileSdk = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                setCompileSdk.invoke(android, 34)
            } catch (e: Exception) {
                try {
                    val setCompileSdkVersion = android.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                    setCompileSdkVersion.invoke(android, 34)
                } catch (ex: Exception) {}
            }
        }
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
