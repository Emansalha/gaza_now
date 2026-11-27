// Some networks cannot reach repo.maven.apache.org (Maven Central): every download
// times out. Send those requests to Google's official mirror of Maven Central instead,
// for the app and for every plugin (their own buildscript blocks included).
val mavenCentralMirror = "https://maven-central.storage-download.googleapis.com/maven2/"

fun RepositoryHandler.useMavenCentralMirror() =
    configureEach {
        if (this is MavenArtifactRepository) {
            val u = url.toString()
            if (u.startsWith("https://repo.maven.apache.org/maven2") || u.startsWith("https://repo1.maven.org/maven2")) {
                setUrl(mavenCentralMirror)
            }
        }
    }

allprojects {
    buildscript.repositories.useMavenCentralMirror()
    repositories.useMavenCentralMirror()
}

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
