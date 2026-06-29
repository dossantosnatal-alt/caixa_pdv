allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = layout.buildDirectory.dir("../../build").get().asFile

subprojects {
    project.layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(project.name))
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
