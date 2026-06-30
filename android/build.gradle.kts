allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

<<<<<<< HEAD
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
=======
rootProject.buildDir = layout.buildDirectory.dir("../../build").get().asFile

subprojects {
    project.layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(project.name))
}

>>>>>>> 5f33b952f513e202af05fcbe9a2199b5687e0803
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
