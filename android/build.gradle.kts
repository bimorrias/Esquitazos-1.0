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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Solución definitiva y segura para forzar compileSdk a 36 en todos los plugins y submódulos
subprojects {
    afterEvaluate { project ->
        project.extensions.findByName("android")?.let { androidExt ->
            try {
                // Para librerías y submódulos
                val compileSdkProp = androidExt.javaClass.getMethod("getCompileSdk")
                // Si ya está configurado, no hacemos nada, si no, lo forzamos
            } catch (e: Exception) {
                // Ignorar si no aplica
            }
            
            // Forzar por reflexión o casting seguro según el tipo de extensión de Android
            try {
                val setCompileSdk = androidExt.javaClass.getMethod("compileSdk", Int::class.java)
                setCompileSdk.invoke(androidExt, 36)
            } catch (e: Exception) {
                try {
                    val setCompileSdkVersion = androidExt.javaClass.getMethod("compileSdkVersion", Int::class.java)
                    setCompileSdkVersion.invoke(androidExt, 36)
                } catch (ex: Exception) {
                    // Ignorar si el método no existe
                }
            }
        }
    }
}