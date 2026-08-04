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

// Plugins such as flutter_keyboard_visibility still declare compileSdk 31.
// Register afterEvaluate before evaluationDependsOn so the callback is queued
// while projects are still unevaluated.
subprojects {
    afterEvaluate {
        if (!plugins.hasPlugin("com.android.library")) return@afterEvaluate
        val android = extensions.findByName("android") ?: return@afterEvaluate
        val boxed = Integer.valueOf(36)
        for (method in android.javaClass.methods) {
            if (method.name != "setCompileSdk" || method.parameterCount != 1) continue
            try {
                method.invoke(android, boxed)
                return@afterEvaluate
            } catch (_: Exception) {
                // Try the next overload.
            }
        }
        android.javaClass.methods
            .firstOrNull { it.name == "setCompileSdkVersion" && it.parameterCount == 1 }
            ?.invoke(android, 36)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
